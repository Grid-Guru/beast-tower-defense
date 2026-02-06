// =============================================================================
// Events — Interface Definition
// =============================================================================
// This is a DESIGN ARTIFACT, not compilable code. It defines the Dojo events
// emitted by the simulation, match, and admin systems.
// =============================================================================

// --- Match Lifecycle Events ---

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct MatchCreated {
    #[key]
    match_id: u32,
    player1: ContractAddress,
    grid_id: u32,
    wager_token: ContractAddress,
    wager_amount: u256,
    budget: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct MatchJoined {
    #[key]
    match_id: u32,
    player2: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct MatchResolved {
    #[key]
    match_id: u32,
    winner: ContractAddress,
    p1_net_score: i32,
    p2_net_score: i32,
    total_ticks_r1: u16,
    total_ticks_r2: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct MatchCancelled {
    #[key]
    match_id: u32,
}

// --- Admin Events ---

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct TokenApproved {
    #[key]
    token: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct TokenRevoked {
    #[key]
    token: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct MapRegistered {
    #[key]
    grid_id: u32,
    width: u8,
    height: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct AdminTransferred {
    #[key]
    previous_admin: ContractAddress,
    new_admin: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct FeeRecipientUpdated {
    #[key]
    new_fee_recipient: ContractAddress,
}

// --- Simulation Events (emitted per-tick for replay/indexing) ---

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct SpawnEvent {
    #[key]
    match_id: u32,
    round: u8,
    tick: u16,
    monster_id: u8,
    monster_tier: u8,
    monster_type: u8,
    tile_x: u8,
    tile_y: u8,
    is_swarm: bool,
    swarm_index: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct DamageEvent {
    #[key]
    match_id: u32,
    round: u8,
    tick: u16,
    tower_id: u8,
    monster_id: u8,
    damage: u32,
    is_crit: bool,
    type_multiplier_num: u8,   // numerator (1 or 3)
    type_multiplier_den: u8,   // denominator (1 or 2)
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct FreezeEvent {
    #[key]
    match_id: u32,
    round: u8,
    tick: u16,
    tower_id: u8,
    monster_id: u8,
    duration: u8,
    is_crit: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct KillEvent {
    #[key]
    match_id: u32,
    round: u8,
    tick: u16,
    tower_id: u8,
    monster_id: u8,
    shield_absorbed: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct EscapeEvent {
    #[key]
    match_id: u32,
    round: u8,
    tick: u16,
    monster_id: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct GameEndEvent {
    #[key]
    match_id: u32,
    round: u8,
    tick: u16,
    winner: u8,           // 0=draw, 1=defender, 2=attacker
    monsters_killed: u16,
    monsters_escaped: u16,
}

// --- Movement Events (optional — high volume, may skip for gas) ---

#[derive(Copy, Drop, Serde)]
#[dojo::event]
struct MoveEvent {
    #[key]
    match_id: u32,
    round: u8,
    tick: u16,
    monster_id: u8,
    from_x: u8,
    from_y: u8,
    to_x: u8,
    to_y: u8,
}
