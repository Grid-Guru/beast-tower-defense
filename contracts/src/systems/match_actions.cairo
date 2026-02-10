use starknet::ContractAddress;
use beast_td::models::beast::{TowerInput, BeastInput};
use beast_td::models::match_state::{MatchResultOutput, MatchView};

#[starknet::interface]
pub trait IMatchActions<T> {
    fn create_match(
        ref self: T,
        grid_id: u32,
        towers: Array<TowerInput>,
        beasts: Array<BeastInput>,
        wager_token: ContractAddress,
        wager_amount: u256,
        budget: u32,
    ) -> u32;
    fn join_match(
        ref self: T, match_id: u32, towers: Array<TowerInput>, beasts: Array<BeastInput>,
    ) -> MatchResultOutput;
    fn cancel_match(ref self: T, match_id: u32);
    fn get_match(self: @T, match_id: u32) -> MatchView;
}

#[dojo::contract]
pub mod match_actions {
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use core::num::traits::Zero;
    use beast_td::models::beast::{TowerInput, BeastInput};
    use beast_td::models::match_state::{
        Match, MatchCounter, MatchStatus, MatchResult, PlayerSetup, PlayerTower, PlayerBeast,
        MatchResultOutput, MatchView,
    };
    use beast_td::models::admin::{AdminConfig, ApprovedToken};
    use beast_td::models::grid::{GameGrid, GridPathTile, GridBlockedTile};
    use beast_td::models::simulation::Tile;
    use beast_td::events::{MatchCreated, MatchJoined, MatchResolved, MatchCancelled};
    use beast_td::utils::constants::{
        ADMIN_CONFIG_ID, MAX_TICKS, MAX_TOWERS, MAX_BEASTS, errors,
    };
    use beast_td::systems::squad::compute_beast_cost;
    use beast_td::systems::simulation::execute_simulation;
    use super::{IMatchActions};

    // ERC20 interface for token transfers
    #[starknet::interface]
    trait IERC20<T> {
        fn transfer_from(
            ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256,
        ) -> bool;
        fn transfer(ref self: T, recipient: ContractAddress, amount: u256) -> bool;
    }

    #[abi(embed_v0)]
    impl MatchActionsImpl of IMatchActions<ContractState> {
        fn create_match(
            ref self: ContractState,
            grid_id: u32,
            towers: Array<TowerInput>,
            beasts: Array<BeastInput>,
            wager_token: ContractAddress,
            wager_amount: u256,
            budget: u32,
        ) -> u32 {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Validate inputs
            assert(wager_amount > 0, errors::ZERO_WAGER);
            assert(budget > 0, errors::ZERO_BUDGET);

            // Validate token approved
            let approved: ApprovedToken = world.read_model(wager_token);
            assert(approved.approved, errors::TOKEN_NOT_APPROVED);

            // Validate grid exists
            let grid: GameGrid = world.read_model(grid_id);
            assert(grid.width > 0, errors::INVALID_GRID);

            // Validate squads
            let towers_span = towers.span();
            let beasts_span = beasts.span();
            assert(towers_span.len() > 0, errors::EMPTY_SQUAD);
            assert(beasts_span.len() > 0, errors::EMPTY_SQUAD);
            assert(towers_span.len() <= MAX_TOWERS.into(), errors::TOO_MANY_TOWERS);
            assert(beasts_span.len() <= MAX_BEASTS.into(), errors::TOO_MANY_BEASTS);

            // Validate tower placements and compute cost
            let tower_cost = self
                .validate_and_cost_towers(@world, grid_id, grid, towers_span, budget);
            let beast_cost = self.validate_and_cost_beasts(beasts_span, budget);
            let total_cost = tower_cost + beast_cost;
            assert(total_cost <= budget, errors::SQUAD_OVER_BUDGET);

            // Escrow wager via ERC20 transfer_from
            let token = IERC20Dispatcher { contract_address: wager_token };
            let success = token
                .transfer_from(caller, get_contract_address(), wager_amount);
            assert(success, errors::TRANSFER_FAILED);

            // Generate match ID
            let mut counter: MatchCounter = world.read_model(1_u8);
            counter.count += 1;
            let match_id = counter.count;
            world.write_model(@MatchCounter { counter_id: 1, count: counter.count });

            // Generate seed from match_id
            let seed: u64 = match_id.into() * 1000000007;

            // Write match
            world
                .write_model(
                    @Match {
                        match_id,
                        player1: caller,
                        player2: Zero::zero(),
                        grid_id,
                        wager_token,
                        wager_amount,
                        budget,
                        status: MatchStatus::AwaitingOpponent,
                        seed,
                        winner: Zero::zero(),
                    },
                );

            // Write player setup
            world
                .write_model(
                    @PlayerSetup {
                        match_id,
                        player: caller,
                        tower_count: towers_span.len().try_into().unwrap(),
                        beast_count: beasts_span.len().try_into().unwrap(),
                        total_cost,
                    },
                );

            // Write individual towers
            let mut i: u8 = 0;
            while i < towers_span.len().try_into().unwrap() {
                let t = *towers_span.at(i.into());
                world
                    .write_model(
                        @PlayerTower {
                            match_id,
                            player: caller,
                            index: i,
                            beast_id: t.beast_id,
                            name: t.name,
                            tier: t.tier,
                            beast_type: t.beast_type,
                            level: t.level,
                            health: t.health,
                            pos_x: t.pos_x,
                            pos_y: t.pos_y,
                        },
                    );
                i += 1;
            };

            // Write individual beasts
            let mut i: u8 = 0;
            while i < beasts_span.len().try_into().unwrap() {
                let b = *beasts_span.at(i.into());
                world
                    .write_model(
                        @PlayerBeast {
                            match_id,
                            player: caller,
                            index: i,
                            beast_id: b.beast_id,
                            name: b.name,
                            tier: b.tier,
                            beast_type: b.beast_type,
                            level: b.level,
                            health: b.health,
                        },
                    );
                i += 1;
            };

            world
                .emit_event(
                    @MatchCreated {
                        match_id, player1: caller, grid_id, wager_token, wager_amount, budget,
                    },
                );

            match_id
        }

        fn join_match(
            ref self: ContractState,
            match_id: u32,
            towers: Array<TowerInput>,
            beasts: Array<BeastInput>,
        ) -> MatchResultOutput {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Read and validate match
            let mut game_match: Match = world.read_model(match_id);
            assert(game_match.player1 != Zero::zero(), errors::MATCH_NOT_FOUND);
            assert(game_match.status == MatchStatus::AwaitingOpponent, errors::MATCH_NOT_AWAITING);
            assert(caller != game_match.player1, errors::CANNOT_JOIN_OWN_MATCH);

            // Validate P2 squads
            let towers_span = towers.span();
            let beasts_span = beasts.span();
            assert(towers_span.len() > 0, errors::EMPTY_SQUAD);
            assert(beasts_span.len() > 0, errors::EMPTY_SQUAD);
            assert(towers_span.len() <= MAX_TOWERS.into(), errors::TOO_MANY_TOWERS);
            assert(beasts_span.len() <= MAX_BEASTS.into(), errors::TOO_MANY_BEASTS);

            let grid: GameGrid = world.read_model(game_match.grid_id);
            let tower_cost = self
                .validate_and_cost_towers(
                    @world, game_match.grid_id, grid, towers_span, game_match.budget,
                );
            let beast_cost = self.validate_and_cost_beasts(beasts_span, game_match.budget);
            let total_cost = tower_cost + beast_cost;
            assert(total_cost <= game_match.budget, errors::SQUAD_OVER_BUDGET);

            // Escrow P2 wager
            let token = IERC20Dispatcher { contract_address: game_match.wager_token };
            let success = token
                .transfer_from(caller, get_contract_address(), game_match.wager_amount);
            assert(success, errors::TRANSFER_FAILED);

            // Write P2 setup
            world
                .write_model(
                    @PlayerSetup {
                        match_id,
                        player: caller,
                        tower_count: towers_span.len().try_into().unwrap(),
                        beast_count: beasts_span.len().try_into().unwrap(),
                        total_cost,
                    },
                );

            let mut i: u8 = 0;
            while i < towers_span.len().try_into().unwrap() {
                let t = *towers_span.at(i.into());
                world
                    .write_model(
                        @PlayerTower {
                            match_id,
                            player: caller,
                            index: i,
                            beast_id: t.beast_id,
                            name: t.name,
                            tier: t.tier,
                            beast_type: t.beast_type,
                            level: t.level,
                            health: t.health,
                            pos_x: t.pos_x,
                            pos_y: t.pos_y,
                        },
                    );
                i += 1;
            };
            let mut i: u8 = 0;
            while i < beasts_span.len().try_into().unwrap() {
                let b = *beasts_span.at(i.into());
                world
                    .write_model(
                        @PlayerBeast {
                            match_id,
                            player: caller,
                            index: i,
                            beast_id: b.beast_id,
                            name: b.name,
                            tier: b.tier,
                            beast_type: b.beast_type,
                            level: b.level,
                            health: b.health,
                        },
                    );
                i += 1;
            };

            // Load path tiles
            let mut path_tiles: Array<Tile> = array![];
            let mut pi: u8 = 0;
            while pi < grid.path_count {
                let pt: GridPathTile = world.read_model((game_match.grid_id, pi));
                path_tiles.append(Tile { x: pt.x, y: pt.y });
                pi += 1;
            };
            let path_span = path_tiles.span();

            // Read P1 setup
            let p1_setup: PlayerSetup = world.read_model((match_id, game_match.player1));
            let p1_towers = self.read_player_towers(@world, match_id, game_match.player1, p1_setup.tower_count);
            let p1_beasts = self.read_player_beasts(@world, match_id, game_match.player1, p1_setup.beast_count);

            let seed_u32: u32 = (game_match.seed & 0xFFFFFFFF).try_into().unwrap();

            // Round 1: P1 defends (P1 towers) vs P2 attacks (P2 beasts)
            let r1 = execute_simulation(
                seed_u32,
                p1_towers.span(),
                beasts.span(),
                path_span,
                grid.start_x,
                grid.start_y,
                grid.end_x,
                grid.end_y,
                grid.width,
                grid.height,
                MAX_TICKS,
            );

            // Round 2: P2 defends (P2 towers) vs P1 attacks (P1 beasts)
            let r2 = execute_simulation(
                seed_u32 + 1,
                towers.span(),
                p1_beasts.span(),
                path_span,
                grid.start_x,
                grid.start_y,
                grid.end_x,
                grid.end_y,
                grid.width,
                grid.height,
                MAX_TICKS,
            );

            // Compute net scores
            // p1_net = r2_escaped (P1's beasts that escaped) - r1_escaped (P2's beasts that
            // escaped)
            let p1_net: i32 = r2.monsters_escaped.into() - r1.monsters_escaped.into();
            let p2_net: i32 = r1.monsters_escaped.into() - r2.monsters_escaped.into();

            // Determine winner
            let admin_config: AdminConfig = world.read_model(ADMIN_CONFIG_ID);
            let winner: ContractAddress = if p1_net > p2_net {
                game_match.player1
            } else if p2_net > p1_net {
                caller
            } else {
                // Tiebreak: lower total squad cost wins
                let p1_total = p1_setup.total_cost;
                let p2_total = total_cost;
                if p1_total < p2_total {
                    game_match.player1
                } else if p2_total < p1_total {
                    caller
                } else {
                    Zero::zero() // draw
                }
            };

            // Payout
            let is_draw = winner.is_zero();
            if is_draw {
                // Refund both players
                token.transfer(game_match.player1, game_match.wager_amount);
                token.transfer(caller, game_match.wager_amount);
            } else {
                let total_pot = game_match.wager_amount * 2;
                let winner_payout = total_pot * 95 / 100;
                let fee = total_pot - winner_payout;
                token.transfer(winner, winner_payout);
                token.transfer(admin_config.fee_recipient, fee);
            };

            // Write match result
            world
                .write_model(
                    @MatchResult {
                        match_id,
                        r1_killed: r1.monsters_killed,
                        r1_escaped: r1.monsters_escaped,
                        r1_ticks: r1.total_ticks,
                        r1_winner: r1.winner,
                        r2_killed: r2.monsters_killed,
                        r2_escaped: r2.monsters_escaped,
                        r2_ticks: r2.total_ticks,
                        r2_winner: r2.winner,
                        final_winner: winner,
                        p1_net_score: p1_net,
                        p2_net_score: p2_net,
                    },
                );

            // Update match
            game_match.player2 = caller;
            game_match.status = MatchStatus::Completed;
            game_match.winner = winner;
            world.write_model(@game_match);

            world.emit_event(@MatchJoined { match_id, player2: caller });
            world
                .emit_event(
                    @MatchResolved {
                        match_id,
                        winner,
                        p1_net_score: p1_net,
                        p2_net_score: p2_net,
                        total_ticks_r1: r1.total_ticks,
                        total_ticks_r2: r2.total_ticks,
                    },
                );

            MatchResultOutput {
                match_id,
                winner,
                p1_attack_score: r2.monsters_escaped,
                p1_defend_score: r1.monsters_killed,
                p2_attack_score: r1.monsters_escaped,
                p2_defend_score: r2.monsters_killed,
                p1_net_score: p1_net,
                p2_net_score: p2_net,
            }
        }

        fn cancel_match(ref self: ContractState, match_id: u32) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let mut game_match: Match = world.read_model(match_id);
            assert(game_match.player1 != Zero::zero(), errors::MATCH_NOT_FOUND);
            assert(caller == game_match.player1, errors::NOT_MATCH_CREATOR);
            assert(game_match.status == MatchStatus::AwaitingOpponent, errors::MATCH_NOT_AWAITING);

            // Refund wager
            let token = IERC20Dispatcher { contract_address: game_match.wager_token };
            token.transfer(game_match.player1, game_match.wager_amount);

            game_match.status = MatchStatus::Cancelled;
            world.write_model(@game_match);
            world.emit_event(@MatchCancelled { match_id, timestamp: starknet::get_block_timestamp() });
        }

        fn get_match(self: @ContractState, match_id: u32) -> MatchView {
            let world = self.world_default();
            let game_match: Match = world.read_model(match_id);

            let status_u8: u8 = match game_match.status {
                MatchStatus::AwaitingOpponent => 0,
                MatchStatus::InProgress => 1,
                MatchStatus::Completed => 2,
                MatchStatus::Cancelled => 3,
            };

            MatchView {
                match_id: game_match.match_id,
                player1: game_match.player1,
                player2: game_match.player2,
                grid_id: game_match.grid_id,
                wager_token: game_match.wager_token,
                wager_amount: game_match.wager_amount,
                budget: game_match.budget,
                status: status_u8,
                winner: game_match.winner,
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"beast_td")
        }

        fn validate_and_cost_towers(
            self: @ContractState,
            world: @dojo::world::WorldStorage,
            grid_id: u32,
            grid: GameGrid,
            towers: Span<TowerInput>,
            budget: u32,
        ) -> u32 {
            let mut total_cost: u32 = 0;
            let mut i: u32 = 0;
            while i < towers.len() {
                let t = *towers.at(i);
                assert(t.tier >= 1 && t.tier <= 5, errors::INVALID_TIER);
                assert(t.beast_type >= 1 && t.beast_type <= 3, errors::INVALID_BEAST_TYPE);
                assert(t.level > 0, errors::ZERO_LEVEL);
                assert(t.health > 0, errors::ZERO_HEALTH);
                assert(
                    t.pos_x < grid.width && t.pos_y < grid.height,
                    errors::INVALID_TOWER_PLACEMENT,
                );

                // Not on path
                let mut pi: u8 = 0;
                while pi < grid.path_count {
                    let pt: GridPathTile = world.read_model((grid_id, pi));
                    assert(
                        !(t.pos_x == pt.x && t.pos_y == pt.y),
                        errors::INVALID_TOWER_PLACEMENT,
                    );
                    pi += 1;
                };

                // Not on blocked
                let mut bi: u8 = 0;
                while bi < grid.blocked_count {
                    let bt: GridBlockedTile = world.read_model((grid_id, bi));
                    assert(
                        !(t.pos_x == bt.x && t.pos_y == bt.y),
                        errors::INVALID_TOWER_PLACEMENT,
                    );
                    bi += 1;
                };

                // No duplicates
                let mut j: u32 = 0;
                while j < i {
                    let other = *towers.at(j);
                    assert(
                        !(t.pos_x == other.pos_x && t.pos_y == other.pos_y),
                        errors::DUPLICATE_TOWER_POSITION,
                    );
                    j += 1;
                };

                total_cost += compute_beast_cost(t.level, t.health);
                i += 1;
            };
            total_cost
        }

        fn validate_and_cost_beasts(
            self: @ContractState, beasts: Span<BeastInput>, budget: u32,
        ) -> u32 {
            let mut total_cost: u32 = 0;
            let mut i: u32 = 0;
            while i < beasts.len() {
                let b = *beasts.at(i);
                assert(b.tier >= 1 && b.tier <= 5, errors::INVALID_TIER);
                assert(b.beast_type >= 1 && b.beast_type <= 3, errors::INVALID_BEAST_TYPE);
                assert(b.level > 0, errors::ZERO_LEVEL);
                assert(b.health > 0, errors::ZERO_HEALTH);
                total_cost += compute_beast_cost(b.level, b.health);
                i += 1;
            };
            total_cost
        }

        fn read_player_towers(
            self: @ContractState,
            world: @dojo::world::WorldStorage,
            match_id: u32,
            player: ContractAddress,
            count: u8,
        ) -> Array<TowerInput> {
            let mut towers: Array<TowerInput> = array![];
            let mut i: u8 = 0;
            while i < count {
                let pt: PlayerTower = world.read_model((match_id, player, i));
                towers
                    .append(
                        TowerInput {
                            beast_id: pt.beast_id,
                            name: pt.name,
                            tier: pt.tier,
                            beast_type: pt.beast_type,
                            level: pt.level,
                            health: pt.health,
                            pos_x: pt.pos_x,
                            pos_y: pt.pos_y,
                        },
                    );
                i += 1;
            };
            towers
        }

        fn read_player_beasts(
            self: @ContractState,
            world: @dojo::world::WorldStorage,
            match_id: u32,
            player: ContractAddress,
            count: u8,
        ) -> Array<BeastInput> {
            let mut beasts: Array<BeastInput> = array![];
            let mut i: u8 = 0;
            while i < count {
                let pb: PlayerBeast = world.read_model((match_id, player, i));
                beasts
                    .append(
                        BeastInput {
                            beast_id: pb.beast_id,
                            name: pb.name,
                            tier: pb.tier,
                            beast_type: pb.beast_type,
                            level: pb.level,
                            health: pb.health,
                        },
                    );
                i += 1;
            };
            beasts
        }
    }
}
