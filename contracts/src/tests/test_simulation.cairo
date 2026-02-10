// =============================================================================
// Simulation Regression Tests — Verify Cairo matches JS SimulationEngine.js
// =============================================================================

use beast_td::models::beast::{TowerInput, BeastInput};
use beast_td::models::simulation::Tile;
use beast_td::systems::simulation::execute_simulation;

/// Helper to build a straight horizontal path
fn straight_path(start_x: u8, end_x: u8, y: u8) -> Array<Tile> {
    let mut tiles: Array<Tile> = array![];
    let mut x = start_x;
    while x <= end_x {
        tiles.append(Tile { x, y });
        x += 1;
    };
    tiles
}

// =============================================================================
// Config 1: Simple 1v1 — T2 tower (hunter, level 50) vs T2 beast (magic, health 30)
// Grid: 5x5, straight path y=2 from (0,2) to (4,2)
// JS result: winner=attacker(2), killed=0, escaped=1, ticks=4
// =============================================================================
#[test]
fn test_simulation_config1_simple_1v1() {
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'tower1', tier: 2, beast_type: 1,
            level: 50, health: 100, pos_x: 2, pos_y: 1,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'beast1', tier: 2, beast_type: 2, level: 10, health: 30 },
    ];
    let path = straight_path(0, 4, 2);

    let result = execute_simulation(
        12345, towers.span(), beasts.span(), path.span(), 0, 2, 4, 2, 5, 5, 1000,
    );

    assert!(result.winner == 2, "Config1: winner should be attacker(2)");
    assert!(result.monsters_killed == 0, "Config1: killed should be 0");
    assert!(result.monsters_escaped == 1, "Config1: escaped should be 1");
    assert!(result.total_ticks == 4, "Config1: ticks should be 4");
}

// =============================================================================
// Config 2: 3 towers vs 3 beasts (T1 freeze + T2 AoE + T5 sniper)
// Grid: 8x5, path y=2 from (0,2) to (7,2)
// JS result: winner=defender(1), killed=2, escaped=0, ticks=1000
// =============================================================================
#[test]
fn test_simulation_config2_multi() {
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'freeze', tier: 1, beast_type: 1,
            level: 40, health: 100, pos_x: 2, pos_y: 1,
        },
        TowerInput {
            beast_id: 2, name: 'aoe', tier: 2, beast_type: 2,
            level: 60, health: 100, pos_x: 4, pos_y: 1,
        },
        TowerInput {
            beast_id: 3, name: 'sniper', tier: 5, beast_type: 3,
            level: 80, health: 100, pos_x: 6, pos_y: 1,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'fast', tier: 2, beast_type: 3, level: 10, health: 50 },
        BeastInput {
            beast_id: 2, name: 'tank', tier: 5, beast_type: 1, level: 20, health: 200,
        },
        BeastInput { beast_id: 3, name: 'slow', tier: 1, beast_type: 2, level: 5, health: 40 },
    ];
    let path = straight_path(0, 7, 2);

    let result = execute_simulation(
        99999, towers.span(), beasts.span(), path.span(), 0, 2, 7, 2, 8, 5, 1000,
    );

    assert!(result.winner == 1, "Config2: winner should be defender(1)");
    assert!(result.monsters_killed == 2, "Config2: killed should be 2");
    assert!(result.monsters_escaped == 0, "Config2: escaped should be 0");
    assert!(result.total_ticks == 1000, "Config2: ticks should be 1000");
}

// =============================================================================
// Config 3: T3 global tower vs T3 swarm
// Grid: 6x3, path y=1 from (0,1) to (5,1)
// JS result: winner=defender(1), killed=4, escaped=0, ticks=15
// =============================================================================
#[test]
fn test_simulation_config3_swarm() {
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'global', tier: 3, beast_type: 1,
            level: 200, health: 100, pos_x: 3, pos_y: 0,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput {
            beast_id: 1, name: 'swarm', tier: 3, beast_type: 3, level: 10, health: 100,
        },
    ];
    let path = straight_path(0, 5, 1);

    let result = execute_simulation(
        42, towers.span(), beasts.span(), path.span(), 0, 1, 5, 1, 6, 3, 1000,
    );

    assert!(result.winner == 1, "Config3: winner should be defender(1)");
    assert!(result.monsters_killed == 4, "Config3: killed should be 4 (swarm)");
    assert!(result.monsters_escaped == 0, "Config3: escaped should be 0");
    assert!(result.total_ticks == 15, "Config3: ticks should be 15");
}

// =============================================================================
// Determinism test — same inputs, same outputs
// =============================================================================
#[test]
fn test_simulation_determinism() {
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 't', tier: 2, beast_type: 1,
            level: 50, health: 100, pos_x: 2, pos_y: 0,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'b', tier: 2, beast_type: 2, level: 10, health: 20 },
    ];
    let path = straight_path(0, 4, 1);

    let r1 = execute_simulation(
        777, towers.span(), beasts.span(), path.span(), 0, 1, 4, 1, 5, 3, 100,
    );
    let r2 = execute_simulation(
        777, towers.span(), beasts.span(), path.span(), 0, 1, 4, 1, 5, 3, 100,
    );

    assert!(r1.winner == r2.winner, "Determinism: same winner");
    assert!(r1.monsters_killed == r2.monsters_killed, "Determinism: same killed");
    assert!(r1.monsters_escaped == r2.monsters_escaped, "Determinism: same escaped");
    assert!(r1.total_ticks == r2.total_ticks, "Determinism: same ticks");
}

// =============================================================================
// Edge case: max_ticks timeout forces winner determination
// =============================================================================
#[test]
fn test_simulation_max_ticks_timeout() {
    // T4 monster with very low move chance - likely won't escape in 5 ticks
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 't', tier: 2, beast_type: 1,
            level: 1, health: 100, pos_x: 5, pos_y: 0,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'b', tier: 4, beast_type: 2, level: 10, health: 9999 },
    ];
    let path = straight_path(0, 10, 1);

    let result = execute_simulation(
        12345, towers.span(), beasts.span(), path.span(), 0, 1, 10, 1, 11, 3, 5,
    );

    // Should finish at exactly max_ticks
    assert!(result.total_ticks == 5, "Should timeout at 5 ticks");
}

// =============================================================================
// Edge case: Empty monster queue
// =============================================================================
#[test]
fn test_simulation_empty_monster_queue() {
    // Tower with no beasts to fight
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'lonely', tier: 2, beast_type: 1,
            level: 50, health: 100, pos_x: 2, pos_y: 1,
        },
    ];
    let beasts: Array<BeastInput> = array![]; // empty queue
    let path = straight_path(0, 4, 2);

    let result = execute_simulation(
        12345, towers.span(), beasts.span(), path.span(), 0, 2, 4, 2, 5, 5, 1000,
    );

    // Should end immediately with draw (0 killed, 0 escaped)
    assert!(result.winner == 0, "Empty queue: should be draw");
    assert!(result.monsters_killed == 0, "Empty queue: killed should be 0");
    assert!(result.monsters_escaped == 0, "Empty queue: escaped should be 0");
    assert!(result.total_ticks == 1, "Empty queue: should end at tick 1");
}

// =============================================================================
// Edge case: Single-tile path (start == end)
// =============================================================================
#[test]
fn test_simulation_single_tile_path() {
    // Monster spawns directly on end tile
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 't', tier: 2, beast_type: 1,
            level: 50, health: 100, pos_x: 1, pos_y: 0,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'instant', tier: 2, beast_type: 2, level: 10, health: 30 },
    ];
    // Path is just one tile (start == end)
    let path: Array<Tile> = array![Tile { x: 2, y: 2 }];

    let result = execute_simulation(
        12345, towers.span(), beasts.span(), path.span(), 2, 2, 2, 2, 5, 5, 1000,
    );

    // Monster should spawn and immediately escape on tick 1
    assert!(result.winner == 2, "Single tile: winner should be attacker(2)");
    assert!(result.monsters_killed == 0, "Single tile: killed should be 0");
    assert!(result.monsters_escaped == 1, "Single tile: escaped should be 1");
    assert!(result.total_ticks == 1, "Single tile: should end at tick 1");
}

// =============================================================================
// Edge case: T3 swarm with health < 5
// =============================================================================
#[test]
fn test_simulation_t3_swarm_low_health() {
    // T3 beast with health=3 should create swarm with ceil(3/5)=1 HP each
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'weak_tower', tier: 2, beast_type: 1,
            level: 10, health: 100, pos_x: 2, pos_y: 0,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'tiny_swarm', tier: 3, beast_type: 3, level: 5, health: 3 },
    ];
    let path = straight_path(0, 5, 1);

    let result = execute_simulation(
        42, towers.span(), beasts.span(), path.span(), 0, 1, 5, 1, 6, 3, 1000,
    );

    // Swarm should spawn with 4 members at 1 HP each
    // Verify simulation completes without errors
    assert!(result.total_ticks > 0, "T3 low health: should complete");
    // Either all killed or all escaped, but total should be 4 swarm members
    let total = result.monsters_killed + result.monsters_escaped;
    assert!(total == 4, "T3 low health: should spawn 4 swarm members");
}

// =============================================================================
// Edge case: Very high health monster
// =============================================================================
#[test]
fn test_simulation_very_high_health() {
    // Monster with health=65000 to test overflow handling
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'weak_tower', tier: 2, beast_type: 1,
            level: 10, health: 100, pos_x: 2, pos_y: 1,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'tank', tier: 1, beast_type: 2, level: 10, health: 65000 },
    ];
    let path = straight_path(0, 10, 2);

    let result = execute_simulation(
        99999, towers.span(), beasts.span(), path.span(), 0, 2, 10, 2, 11, 5, 100,
    );

    // Should complete without overflow errors
    assert!(result.total_ticks > 0, "High health: should complete");
    // Monster likely escapes given weak tower and high health
    let total = result.monsters_killed + result.monsters_escaped;
    assert!(total == 1, "High health: should have 1 monster");
}

// =============================================================================
// Edge case: Max ticks timeout with active monsters still alive
// =============================================================================
#[test]
fn test_simulation_max_ticks_with_alive_monsters() {
    // T5 tank with shield vs weak tower, limit to 10 ticks
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'weak', tier: 2, beast_type: 1,
            level: 5, health: 100, pos_x: 3, pos_y: 0,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'tank', tier: 5, beast_type: 3, level: 50, health: 5000 },
    ];
    let path = straight_path(0, 8, 1);

    let result = execute_simulation(
        777, towers.span(), beasts.span(), path.span(), 0, 1, 8, 1, 9, 3, 10,
    );

    // Should timeout at max_ticks and determine winner
    assert!(result.total_ticks == 10, "Max ticks alive: should timeout at 10");
    assert!(result.winner != 255, "Max ticks alive: winner should be determined");
    // Winner determined by killed vs escaped
    if result.monsters_killed > result.monsters_escaped {
        assert!(result.winner == 1, "Max ticks alive: defender should win if killed > escaped");
    } else if result.monsters_escaped > result.monsters_killed {
        assert!(result.winner == 2, "Max ticks alive: attacker should win if escaped > killed");
    } else {
        assert!(result.winner == 0, "Max ticks alive: should be draw if equal");
    }
}

// =============================================================================
// T062: Reference GameGrid — 10x10 winding path helper
// =============================================================================

/// Build a winding path across a 10x10 grid:
///   Row 1: (0,1) → (7,1)   [left to right]
///   Col 7: (7,1) → (7,3)   [down turn]
///   Row 3: (7,3) → (2,3)   [right to left]
///   Col 2: (2,3) → (2,5)   [down turn]
///   Row 5: (2,5) → (9,5)   [left to right, exit]
/// Total: 8 + 2 + 5 + 2 + 7 = 24 tiles
/// Start: (0,1), End: (9,5)
fn winding_path_10x10() -> Array<Tile> {
    let mut tiles: Array<Tile> = array![];
    // Row 1: x=0..7, y=1
    let mut x: u8 = 0;
    while x <= 7 {
        tiles.append(Tile { x, y: 1 });
        x += 1;
    };
    // Col 7: y=2..3 (7,1 already added)
    tiles.append(Tile { x: 7, y: 2 });
    tiles.append(Tile { x: 7, y: 3 });
    // Row 3: x=6..2 (7,3 already added)
    let mut x2: u8 = 6;
    while x2 >= 2 {
        tiles.append(Tile { x: x2, y: 3 });
        if x2 == 0 {
            break;
        }
        x2 -= 1;
    };
    // Col 2: y=4..5 (2,3 already added)
    tiles.append(Tile { x: 2, y: 4 });
    tiles.append(Tile { x: 2, y: 5 });
    // Row 5: x=3..9 (2,5 already added)
    let mut x3: u8 = 3;
    while x3 <= 9 {
        tiles.append(Tile { x: x3, y: 5 });
        x3 += 1;
    };
    tiles
}

#[test]
fn test_reference_grid_winding_path() {
    // Verify the winding path has expected length and works in simulation
    let path = winding_path_10x10();
    assert!(path.len() == 24, "Winding path should have 24 tiles");

    // Place towers along the winding path to test gameplay
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'freeze', tier: 1, beast_type: 1,
            level: 30, health: 100, pos_x: 3, pos_y: 0,
        },
        TowerInput {
            beast_id: 2, name: 'aoe', tier: 2, beast_type: 2,
            level: 50, health: 100, pos_x: 5, pos_y: 2,
        },
        TowerInput {
            beast_id: 3, name: 'global', tier: 3, beast_type: 3,
            level: 100, health: 100, pos_x: 5, pos_y: 4,
        },
    ];
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'fast', tier: 2, beast_type: 3, level: 10, health: 50 },
        BeastInput { beast_id: 2, name: 'tank', tier: 5, beast_type: 1, level: 20, health: 200 },
    ];

    let result = execute_simulation(
        42, towers.span(), beasts.span(), path.span(), 0, 1, 9, 5, 10, 10, 1000,
    );

    // Should complete without errors on a winding map
    assert!(result.total_ticks > 0, "Winding path: should complete");
    let total = result.monsters_killed + result.monsters_escaped;
    assert!(total > 0, "Winding path: should process monsters");
}

// =============================================================================
// T063: Gas benchmark — worst-case simulation
// 5 towers (T1-T5 including T3 global), 5 beasts (including T3 swarm = 20 monsters)
// Long path, 1000 ticks max — captures gas to verify Starknet limits
// =============================================================================
#[test]
fn test_gas_benchmark_worst_case() {
    // 5 towers covering all tiers
    let towers: Array<TowerInput> = array![
        TowerInput {
            beast_id: 1, name: 'freeze', tier: 1, beast_type: 1,
            level: 50, health: 100, pos_x: 3, pos_y: 0,
        },
        TowerInput {
            beast_id: 2, name: 'aoe', tier: 2, beast_type: 2,
            level: 60, health: 100, pos_x: 6, pos_y: 0,
        },
        TowerInput {
            beast_id: 3, name: 'global', tier: 3, beast_type: 3,
            level: 80, health: 100, pos_x: 9, pos_y: 0,
        },
        TowerInput {
            beast_id: 4, name: 'double', tier: 4, beast_type: 1,
            level: 40, health: 100, pos_x: 12, pos_y: 0,
        },
        TowerInput {
            beast_id: 5, name: 'sniper', tier: 5, beast_type: 2,
            level: 70, health: 100, pos_x: 15, pos_y: 0,
        },
    ];

    // 5 beasts including T3 swarm (spawns 4 each = 20 potential monsters)
    let beasts: Array<BeastInput> = array![
        BeastInput { beast_id: 1, name: 'fast', tier: 2, beast_type: 3, level: 10, health: 80 },
        BeastInput { beast_id: 2, name: 'swarm1', tier: 3, beast_type: 1, level: 15, health: 100 },
        BeastInput { beast_id: 3, name: 'swarm2', tier: 3, beast_type: 2, level: 15, health: 100 },
        BeastInput {
            beast_id: 4, name: 'shield', tier: 5, beast_type: 3, level: 20, health: 300,
        },
        BeastInput { beast_id: 5, name: 'slow', tier: 1, beast_type: 1, level: 5, health: 60 },
    ];

    // Long straight path (20 tiles)
    let path = straight_path(0, 19, 1);

    let result = execute_simulation(
        12345, towers.span(), beasts.span(), path.span(), 0, 1, 19, 1, 20, 3, 1000,
    );

    // Verify simulation completed
    assert!(result.total_ticks > 0, "Benchmark: should complete");
    assert!(result.winner != 255, "Benchmark: winner should be determined");
    // With 2 T3 swarms, expect up to 8 swarm + 3 regular = 11 total monsters processed
    let total = result.monsters_killed + result.monsters_escaped;
    assert!(total > 0, "Benchmark: should process monsters");
}
