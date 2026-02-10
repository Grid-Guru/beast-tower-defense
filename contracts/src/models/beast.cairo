// =============================================================================
// Beast Type Enum
// =============================================================================

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum BeastType {
    Hunter,  // 1
    Magic,   // 2
    Brute,   // 3
}

pub impl BeastTypeIntoU8 of Into<BeastType, u8> {
    fn into(self: BeastType) -> u8 {
        match self {
            BeastType::Hunter => 1,
            BeastType::Magic => 2,
            BeastType::Brute => 3,
        }
    }
}

pub fn beast_type_from_u8(value: u8) -> BeastType {
    if value == 1 {
        BeastType::Hunter
    } else if value == 2 {
        BeastType::Magic
    } else {
        BeastType::Brute
    }
}

// =============================================================================
// Input Structs (passed into simulation/match functions)
// =============================================================================

#[derive(Copy, Drop, Serde)]
pub struct TowerInput {
    pub beast_id: u32,
    pub name: felt252,
    pub tier: u8,
    pub beast_type: u8, // 1=Hunter, 2=Magic, 3=Brute
    pub level: u16,
    pub health: u32,
    pub pos_x: u8,
    pub pos_y: u8,
}

#[derive(Copy, Drop, Serde)]
pub struct BeastInput {
    pub beast_id: u32,
    pub name: felt252,
    pub tier: u8,
    pub beast_type: u8,
    pub level: u16,
    pub health: u32,
}

// =============================================================================
// Simulation Result (output of run_simulation)
// =============================================================================

#[derive(Copy, Drop, Serde)]
pub struct SimulationResult {
    pub winner: u8,            // 0=draw, 1=defender, 2=attacker
    pub monsters_killed: u16,
    pub monsters_escaped: u16,
    pub total_ticks: u16,
}
