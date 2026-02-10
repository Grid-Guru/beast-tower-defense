use starknet::ContractAddress;

// =============================================================================
// Match Status Enum
// =============================================================================

#[derive(Copy, Drop, Serde, PartialEq, Introspect, Default, DojoStore)]
pub enum MatchStatus {
    #[default]
    AwaitingOpponent,
    InProgress,
    Completed,
    Cancelled,
}

// =============================================================================
// Match Model (Dojo persistent)
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Match {
    #[key]
    pub match_id: u32,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub grid_id: u32,
    pub wager_token: ContractAddress,
    pub wager_amount: u256,
    pub budget: u32,
    pub status: MatchStatus,
    pub seed: u64,
    pub winner: ContractAddress,
}

// =============================================================================
// Match Counter (for auto-incrementing match IDs)
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MatchCounter {
    #[key]
    pub counter_id: u8, // always 1
    pub count: u32,
}

// =============================================================================
// Player Setup Models (Dojo persistent)
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerSetup {
    #[key]
    pub match_id: u32,
    #[key]
    pub player: ContractAddress,
    pub tower_count: u8,
    pub beast_count: u8,
    pub total_cost: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerTower {
    #[key]
    pub match_id: u32,
    #[key]
    pub player: ContractAddress,
    #[key]
    pub index: u8,
    pub beast_id: u32,
    pub name: felt252,
    pub tier: u8,
    pub beast_type: u8,
    pub level: u16,
    pub health: u32,
    pub pos_x: u8,
    pub pos_y: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerBeast {
    #[key]
    pub match_id: u32,
    #[key]
    pub player: ContractAddress,
    #[key]
    pub index: u8,
    pub beast_id: u32,
    pub name: felt252,
    pub tier: u8,
    pub beast_type: u8,
    pub level: u16,
    pub health: u32,
}

// =============================================================================
// Match Result Model (Dojo persistent)
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MatchResult {
    #[key]
    pub match_id: u32,
    pub r1_killed: u16,
    pub r1_escaped: u16,
    pub r1_ticks: u16,
    pub r1_winner: u8,
    pub r2_killed: u16,
    pub r2_escaped: u16,
    pub r2_ticks: u16,
    pub r2_winner: u8,
    pub final_winner: ContractAddress,
    pub p1_net_score: i32,
    pub p2_net_score: i32,
}

// =============================================================================
// Output / View Structs (not persisted)
// =============================================================================

#[derive(Copy, Drop, Serde)]
pub struct MatchResultOutput {
    pub match_id: u32,
    pub winner: ContractAddress,
    pub p1_attack_score: u16,
    pub p1_defend_score: u16,
    pub p2_attack_score: u16,
    pub p2_defend_score: u16,
    pub p1_net_score: i32,
    pub p2_net_score: i32,
}

#[derive(Copy, Drop, Serde)]
pub struct MatchView {
    pub match_id: u32,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub grid_id: u32,
    pub wager_token: ContractAddress,
    pub wager_amount: u256,
    pub budget: u32,
    pub status: u8,
    pub winner: ContractAddress,
}
