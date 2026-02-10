// =============================================================================
// Simulation Runtime Structs — NOT Dojo models, exist only during execution
// =============================================================================

#[derive(Copy, Drop, Serde)]
pub struct Tower {
    pub id: u8,
    pub tier: u8,
    pub beast_type: u8,
    pub level: u16,
    pub health: u32,
    pub pos_x: u8,
    pub pos_y: u8,
    pub attack_counter: u8,
    pub crit_chance: u8, // percentage (0-100), default 20
    pub range: u8,
}

#[derive(Copy, Drop, Serde)]
pub struct Monster {
    pub id: u8,
    pub tier: u8,
    pub beast_type: u8,
    pub level: u16,
    pub health: i64,
    pub max_health: u32,
    pub pos_x: u8,
    pub pos_y: u8,
    pub last_x: u8,
    pub last_y: u8,
    pub has_last_tile: bool,
    pub alive: bool,
    pub freeze_ticks: u8,
    pub shield: u32,
    pub spawn_tick: u16,
}

#[derive(Copy, Drop, Serde)]
pub struct SimulationState {
    pub rng_state: u32,
    pub current_tick: u16,
    pub monsters_escaped: u16,
    pub monsters_killed: u16,
    pub finished: bool,
    pub winner: u8, // 0=draw, 1=defender, 2=attacker
}

// Tile coordinate pair for path/position tracking
#[derive(Copy, Drop, Serde)]
pub struct Tile {
    pub x: u8,
    pub y: u8,
}

// Queue entry for monster spawning
#[derive(Copy, Drop, Serde)]
pub struct QueueEntry {
    pub id: u8,
    pub name: felt252,
    pub tier: u8,
    pub beast_type: u8,
    pub level: u16,
    pub health: u32,
    pub is_swarm: bool,
}
