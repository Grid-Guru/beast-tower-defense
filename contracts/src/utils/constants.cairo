// =============================================================================
// Game Constants
// =============================================================================

// Tower tier configs: attack_speed (ticks between attacks)
pub const T1_ATTACK_SPEED: u8 = 2;
pub const T2_ATTACK_SPEED: u8 = 1;
pub const T3_ATTACK_SPEED: u8 = 1;
pub const T4_ATTACK_SPEED: u8 = 1; // special: always fires
pub const T5_ATTACK_SPEED: u8 = 2;

// Tower tier configs: range (Manhattan distance)
pub const T1_RANGE: u8 = 1;
pub const T2_RANGE: u8 = 1;
pub const T3_RANGE: u8 = 0; // global — hits all alive monsters
pub const T4_RANGE: u8 = 1;
pub const T5_RANGE: u8 = 3;

// Monster tier configs: step_ticks (ticks between moves)
pub const T1_STEP_TICKS: u8 = 4;
pub const T2_STEP_TICKS: u8 = 1;
pub const T3_STEP_TICKS: u8 = 5;
pub const T4_STEP_TICKS: u8 = 1; // 10% chance to move
pub const T5_STEP_TICKS: u8 = 3;

// Combat parameters
pub const DEFAULT_CRIT_CHANCE: u8 = 20; // 20%
pub const SWARM_COUNT: u8 = 4;
pub const SWARM_HEALTH_DIVISOR: u32 = 5;
pub const SHIELD_HEALTH_PCT: u32 = 50;
pub const T4_MOVE_CHANCE_PCT: u8 = 10;
pub const T4_TELEPORT_CHANCE_PCT: u8 = 10;
pub const T4_TELEPORT_TILES: u8 = 2;

// Game limits
pub const MAX_TICKS: u16 = 1000;
pub const MAX_TOWERS: u8 = 5;
pub const MAX_BEASTS: u8 = 5;
pub const MAX_GRID_SIZE: u8 = 32;
pub const MAX_PATH_LENGTH: u8 = 64;

// Economy
pub const WAGER_FEE_PCT: u8 = 5;

// Admin
pub const ADMIN_CONFIG_ID: u8 = 1;

// Tower attack speed helper
pub fn get_attack_speed(tier: u8) -> u8 {
    if tier == 1 {
        T1_ATTACK_SPEED
    } else if tier == 2 {
        T2_ATTACK_SPEED
    } else if tier == 3 {
        T3_ATTACK_SPEED
    } else if tier == 4 {
        T4_ATTACK_SPEED
    } else {
        T5_ATTACK_SPEED
    }
}

// Tower range helper
pub fn get_range(tier: u8) -> u8 {
    if tier == 1 {
        T1_RANGE
    } else if tier == 2 {
        T2_RANGE
    } else if tier == 3 {
        T3_RANGE
    } else if tier == 4 {
        T4_RANGE
    } else {
        T5_RANGE
    }
}

// Monster step ticks helper
pub fn get_step_ticks(tier: u8) -> u8 {
    if tier == 1 {
        T1_STEP_TICKS
    } else if tier == 2 {
        T2_STEP_TICKS
    } else if tier == 3 {
        T3_STEP_TICKS
    } else if tier == 4 {
        T4_STEP_TICKS
    } else {
        T5_STEP_TICKS
    }
}

// Error strings
pub mod errors {
    pub const NOT_ADMIN: felt252 = 'NOT_ADMIN';
    pub const ZERO_ADDRESS: felt252 = 'ZERO_ADDRESS';
    pub const GRID_ALREADY_EXISTS: felt252 = 'GRID_ALREADY_EXISTS';
    pub const INVALID_GRID_SIZE: felt252 = 'INVALID_GRID_SIZE';
    pub const INVALID_PATH: felt252 = 'INVALID_PATH';
    pub const PATH_BLOCKED_OVERLAP: felt252 = 'PATH_BLOCKED_OVERLAP';
    pub const INVALID_GRID: felt252 = 'INVALID_GRID';
    pub const EMPTY_SQUAD: felt252 = 'EMPTY_SQUAD';
    pub const INVALID_TOWER_PLACEMENT: felt252 = 'INVALID_TOWER_PLACEMENT';
    pub const DUPLICATE_TOWER_POSITION: felt252 = 'DUPLICATE_TOWER_POSITION';
    pub const SQUAD_OVER_BUDGET: felt252 = 'SQUAD_OVER_BUDGET';
    pub const ZERO_WAGER: felt252 = 'ZERO_WAGER';
    pub const ZERO_BUDGET: felt252 = 'ZERO_BUDGET';
    pub const TOKEN_NOT_APPROVED: felt252 = 'TOKEN_NOT_APPROVED';
    pub const TRANSFER_FAILED: felt252 = 'TRANSFER_FAILED';
    pub const MATCH_NOT_FOUND: felt252 = 'MATCH_NOT_FOUND';
    pub const MATCH_NOT_AWAITING: felt252 = 'MATCH_NOT_AWAITING';
    pub const CANNOT_JOIN_OWN_MATCH: felt252 = 'CANNOT_JOIN_OWN_MATCH';
    pub const NOT_MATCH_CREATOR: felt252 = 'NOT_MATCH_CREATOR';
    pub const INVALID_TIER: felt252 = 'INVALID_TIER';
    pub const INVALID_BEAST_TYPE: felt252 = 'INVALID_BEAST_TYPE';
    pub const ZERO_HEALTH: felt252 = 'ZERO_HEALTH';
    pub const ZERO_LEVEL: felt252 = 'ZERO_LEVEL';
    pub const TOO_MANY_TOWERS: felt252 = 'TOO_MANY_TOWERS';
    pub const TOO_MANY_BEASTS: felt252 = 'TOO_MANY_BEASTS';
    pub const OUT_OF_BOUNDS: felt252 = 'OUT_OF_BOUNDS';
    pub const TOWER_ON_PATH: felt252 = 'TOWER_ON_PATH';
    pub const TOWER_ON_BLOCKED: felt252 = 'TOWER_ON_BLOCKED';
}
