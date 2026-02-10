use beast_td::models::beast::{TowerInput, BeastInput};

#[starknet::interface]
pub trait ISquad<T> {
    fn validate_towers(
        self: @T, grid_id: u32, towers: Array<TowerInput>, budget: u32,
    ) -> (bool, u32);
    fn validate_beasts(self: @T, beasts: Array<BeastInput>, budget: u32) -> (bool, u32);
    fn beast_cost(self: @T, level: u16, health: u32) -> u32;
}

/// Calculate beast cost: level + health
pub fn compute_beast_cost(level: u16, health: u32) -> u32 {
    let level_u32: u32 = level.into();
    level_u32 + health
}

/// Validate a single beast's attributes.
fn validate_beast_attrs(tier: u8, beast_type: u8, level: u16, health: u32) {
    use beast_td::utils::constants::errors;
    assert(tier >= 1 && tier <= 5, errors::INVALID_TIER);
    assert(beast_type >= 1 && beast_type <= 3, errors::INVALID_BEAST_TYPE);
    assert(level > 0, errors::ZERO_LEVEL);
    assert(health > 0, errors::ZERO_HEALTH);
}

#[dojo::contract]
pub mod squad {
    use dojo::model::ModelStorage;
    use beast_td::models::beast::{TowerInput, BeastInput};
    use beast_td::models::grid::{GameGrid, GridPathTile, GridBlockedTile};
    use beast_td::utils::constants::{MAX_TOWERS, MAX_BEASTS, errors};
    use super::{ISquad, compute_beast_cost, validate_beast_attrs};

    #[abi(embed_v0)]
    impl SquadImpl of ISquad<ContractState> {
        fn validate_towers(
            self: @ContractState, grid_id: u32, towers: Array<TowerInput>, budget: u32,
        ) -> (bool, u32) {
            let world = self.world_default();

            // Check not empty
            assert(towers.len() > 0, errors::EMPTY_SQUAD);
            assert(towers.len() <= MAX_TOWERS.into(), errors::TOO_MANY_TOWERS);

            // Read grid
            let grid: GameGrid = world.read_model(grid_id);
            assert(grid.width > 0, errors::INVALID_GRID);

            let towers_span = towers.span();
            let mut total_cost: u32 = 0;
            let mut i: u32 = 0;

            while i < towers_span.len() {
                let t = *towers_span.at(i);

                // Validate attributes
                validate_beast_attrs(t.tier, t.beast_type, t.level, t.health);

                // Validate position in bounds
                assert(t.pos_x < grid.width && t.pos_y < grid.height, errors::OUT_OF_BOUNDS);

                // Validate not on path tile
                let mut pi: u8 = 0;
                while pi < grid.path_count {
                    let pt: GridPathTile = world.read_model((grid_id, pi));
                    assert(!(t.pos_x == pt.x && t.pos_y == pt.y), errors::TOWER_ON_PATH);
                    pi += 1;
                };

                // Validate not on blocked tile
                let mut bi: u8 = 0;
                while bi < grid.blocked_count {
                    let bt: GridBlockedTile = world.read_model((grid_id, bi));
                    assert(!(t.pos_x == bt.x && t.pos_y == bt.y), errors::TOWER_ON_BLOCKED);
                    bi += 1;
                };

                // Check no duplicate positions
                let mut j: u32 = 0;
                while j < i {
                    let other = *towers_span.at(j);
                    assert(
                        !(t.pos_x == other.pos_x && t.pos_y == other.pos_y),
                        errors::DUPLICATE_TOWER_POSITION,
                    );
                    j += 1;
                };

                total_cost += compute_beast_cost(t.level, t.health);
                i += 1;
            };

            let valid = total_cost <= budget;
            (valid, total_cost)
        }

        fn validate_beasts(
            self: @ContractState, beasts: Array<BeastInput>, budget: u32,
        ) -> (bool, u32) {
            assert(beasts.len() > 0, errors::EMPTY_SQUAD);
            assert(beasts.len() <= MAX_BEASTS.into(), errors::TOO_MANY_BEASTS);

            let beasts_span = beasts.span();
            let mut total_cost: u32 = 0;
            let mut i: u32 = 0;

            while i < beasts_span.len() {
                let b = *beasts_span.at(i);
                validate_beast_attrs(b.tier, b.beast_type, b.level, b.health);
                total_cost += compute_beast_cost(b.level, b.health);
                i += 1;
            };

            let valid = total_cost <= budget;
            (valid, total_cost)
        }

        fn beast_cost(self: @ContractState, level: u16, health: u32) -> u32 {
            compute_beast_cost(level, health)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"beast_td")
        }
    }
}
