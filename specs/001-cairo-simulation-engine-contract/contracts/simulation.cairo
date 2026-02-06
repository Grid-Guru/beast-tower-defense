// =============================================================================
// Simulation System — Interface Definition
// =============================================================================
// This is a DESIGN ARTIFACT, not compilable code. It defines the contract
// interface for the core simulation engine.
// =============================================================================

/// Core simulation system interface.
/// Executes the deterministic tick-based game simulation.
#[starknet::interface]
trait ISimulation<T> {
    /// Run a full simulation with the given configuration.
    /// Returns (winner: u8, monsters_killed: u16, monsters_escaped: u16, total_ticks: u16)
    ///
    /// Parameters:
    /// - seed: u32 — PRNG seed for deterministic execution
    /// - grid_id: u32 — ID of the registered GameGrid
    /// - towers: Array<TowerInput> — defender tower placements
    /// - beasts: Array<BeastInput> — attacker beast queue
    /// - max_ticks: u16 — maximum simulation ticks (default 1000)
    ///
    /// Returns: SimulationResult struct
    ///
    /// Emits: SpawnEvent, DamageEvent, FreezeEvent, KillEvent, EscapeEvent, GameEndEvent
    fn run_simulation(
        ref self: T,
        seed: u32,
        grid_id: u32,
        towers: Array<TowerInput>,
        beasts: Array<BeastInput>,
        max_ticks: u16,
    ) -> SimulationResult;
}

/// Input struct for a tower placement
struct TowerInput {
    beast_id: u32,
    name: felt252,
    tier: u8,
    beast_type: u8,   // 1=Hunter, 2=Magic, 3=Brute
    level: u16,
    health: u32,
    pos_x: u8,
    pos_y: u8,
}

/// Input struct for an attacker beast
struct BeastInput {
    beast_id: u32,
    name: felt252,
    tier: u8,
    beast_type: u8,
    level: u16,
    health: u32,
}

/// Output struct for simulation result
struct SimulationResult {
    winner: u8,            // 0=draw, 1=defender, 2=attacker
    monsters_killed: u16,
    monsters_escaped: u16,
    total_ticks: u16,
}

// =============================================================================
// Internal Simulation Functions (not exposed via interface)
// =============================================================================
//
// fn tick(ref state: SimulationState, ref towers, ref monsters, ref queue, grid)
//   1. spawn_monster(ref state, ref monsters, ref queue, grid)
//   2. process_tower_attacks(ref state, ref towers, ref monsters, rng)
//   3. process_monster_movement(ref state, ref monsters, grid, rng)
//   4. cleanup_dead_monsters(ref monsters)
//   5. check_win_condition(ref state, queue, monsters) -> bool
//
// fn tower_attack(ref state, tower, ref monsters, ref rng)
//   - Dispatches to tier-specific attack function
//
// fn tower_tier1_attack(tower, ref monsters, ref rng) — Freeze
// fn tower_tier2_attack(tower, ref monsters, ref rng) — AoE burst
// fn tower_tier3_attack(tower, ref monsters, ref rng) — Global
// fn tower_tier4_attack(tower, ref monsters, ref rng) — Double-shot
// fn tower_tier5_attack(tower, ref monsters, ref rng) — Tank-buster
//
// fn move_monster(ref monster, grid, ref rng, current_tick)
// fn apply_damage(ref monster, damage, ref state)
// fn get_type_multiplier(attacker_type, defender_type) -> (u8, u8)  // (num, denom)
// fn within_manhattan(x1, y1, x2, y2, range) -> bool
// fn get_adjacent_path_tiles(x, y, grid) -> Array<(u8, u8)>
// fn rng_next(ref state: u32) -> u32  // Mulberry32 step
