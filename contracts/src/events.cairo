use starknet::ContractAddress;

// =============================================================================
// Match Lifecycle Events
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MatchCreated {
    #[key]
    pub match_id: u32,
    pub player1: ContractAddress,
    pub grid_id: u32,
    pub wager_token: ContractAddress,
    pub wager_amount: u256,
    pub budget: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MatchJoined {
    #[key]
    pub match_id: u32,
    pub player2: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MatchResolved {
    #[key]
    pub match_id: u32,
    pub winner: ContractAddress,
    pub p1_net_score: i32,
    pub p2_net_score: i32,
    pub total_ticks_r1: u16,
    pub total_ticks_r2: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MatchCancelled {
    #[key]
    pub match_id: u32,
    pub timestamp: u64,
}

// =============================================================================
// Admin Events
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct TokenApproved {
    #[key]
    pub token: ContractAddress,
    pub approved: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct TokenRevoked {
    #[key]
    pub token: ContractAddress,
    pub revoked: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MapRegistered {
    #[key]
    pub grid_id: u32,
    pub width: u8,
    pub height: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AdminTransferred {
    #[key]
    pub previous_admin: ContractAddress,
    pub new_admin: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct FeeRecipientUpdated {
    #[key]
    pub new_fee_recipient: ContractAddress,
    pub updated: bool,
}

// =============================================================================
// Simulation Events (emitted per-tick for replay/indexing)
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SpawnEvent {
    #[key]
    pub match_id: u32,
    pub round: u8,
    pub tick: u16,
    pub monster_id: u8,
    pub monster_tier: u8,
    pub monster_type: u8,
    pub tile_x: u8,
    pub tile_y: u8,
    pub is_swarm: bool,
    pub swarm_index: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct DamageEvent {
    #[key]
    pub match_id: u32,
    pub round: u8,
    pub tick: u16,
    pub tower_id: u8,
    pub monster_id: u8,
    pub damage: u32,
    pub is_crit: bool,
    pub type_multiplier_num: u8,
    pub type_multiplier_den: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct FreezeEvent {
    #[key]
    pub match_id: u32,
    pub round: u8,
    pub tick: u16,
    pub tower_id: u8,
    pub monster_id: u8,
    pub duration: u8,
    pub is_crit: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct KillEvent {
    #[key]
    pub match_id: u32,
    pub round: u8,
    pub tick: u16,
    pub tower_id: u8,
    pub monster_id: u8,
    pub shield_absorbed: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct EscapeEvent {
    #[key]
    pub match_id: u32,
    pub round: u8,
    pub tick: u16,
    pub monster_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GameEndEvent {
    #[key]
    pub match_id: u32,
    pub round: u8,
    pub tick: u16,
    pub winner: u8,
    pub monsters_killed: u16,
    pub monsters_escaped: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MoveEvent {
    #[key]
    pub match_id: u32,
    pub round: u8,
    pub tick: u16,
    pub monster_id: u8,
    pub from_x: u8,
    pub from_y: u8,
    pub to_x: u8,
    pub to_y: u8,
}
