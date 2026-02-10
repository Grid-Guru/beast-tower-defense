use beast_td::models::beast::{TowerInput, BeastInput, SimulationResult};
use beast_td::models::simulation::{Tower, Monster, SimulationState, Tile, QueueEntry};
use beast_td::utils::rng;
use beast_td::utils::math;
use beast_td::utils::constants;

// =============================================================================
// Simulation Interface
// =============================================================================

#[starknet::interface]
pub trait ISimulation<T> {
    fn run_simulation(
        ref self: T,
        seed: u32,
        grid_id: u32,
        towers: Array<TowerInput>,
        beasts: Array<BeastInput>,
        max_ticks: u16,
    ) -> SimulationResult;
}

// =============================================================================
// Internal simulation logic (pure functions, no world access)
// =============================================================================

/// Get 4-directional adjacent path tiles for a position.
fn get_adjacent_path_tiles(
    x: u8, y: u8, path_tiles: Span<Tile>,
) -> Array<Tile> {
    let mut result: Array<Tile> = array![];
    // Up: (x, y-1)
    if y > 0 {
        if is_path_tile(x, y - 1, path_tiles) {
            result.append(Tile { x, y: y - 1 });
        }
    }
    // Down: (x, y+1)
    if is_path_tile(x, y + 1, path_tiles) {
        result.append(Tile { x, y: y + 1 });
    }
    // Left: (x-1, y)
    if x > 0 {
        if is_path_tile(x - 1, y, path_tiles) {
            result.append(Tile { x: x - 1, y });
        }
    }
    // Right: (x+1, y)
    if is_path_tile(x + 1, y, path_tiles) {
        result.append(Tile { x: x + 1, y });
    }
    result
}

/// Check if a coordinate is a path tile.
fn is_path_tile(x: u8, y: u8, path_tiles: Span<Tile>) -> bool {
    let mut i: u32 = 0;
    let len = path_tiles.len();
    let mut found = false;
    while i < len {
        let tile = *path_tiles.at(i);
        if tile.x == x && tile.y == y {
            found = true;
            break;
        }
        i += 1;
    };
    found
}

/// Check if position is the end tile.
fn is_end_tile(x: u8, y: u8, end_x: u8, end_y: u8) -> bool {
    x == end_x && y == end_y
}

/// Sort tile keys deterministically: by x ascending, then y ascending.
fn sort_tiles(tiles: Array<Tile>) -> Array<Tile> {
    let len = tiles.len();
    if len <= 1 {
        return tiles;
    }
    // Simple insertion sort (small arrays)
    let mut sorted: Array<Tile> = array![];
    let mut i: u32 = 0;
    while i < len {
        sorted.append(*tiles.at(i));
        i += 1;
    };

    let mut i: u32 = 1;
    while i < len {
        let mut j: u32 = i;
        while j > 0 {
            let a = *sorted.at(j - 1);
            let b = *sorted.at(j);
            let should_swap = if a.x > b.x {
                true
            } else if a.x == b.x && a.y > b.y {
                true
            } else {
                false
            };
            if should_swap {
                // Rebuild with swap
                let mut new_sorted: Array<Tile> = array![];
                let mut k: u32 = 0;
                while k < len {
                    if k == j - 1 {
                        new_sorted.append(b);
                    } else if k == j {
                        new_sorted.append(a);
                    } else {
                        new_sorted.append(*sorted.at(k));
                    }
                    k += 1;
                };
                sorted = new_sorted;
                j -= 1;
            } else {
                break;
            }
        };
        i += 1;
    };
    sorted
}

/// Build Tower runtime struct from TowerInput.
fn build_tower(input: TowerInput, id: u8) -> Tower {
    Tower {
        id,
        tier: input.tier,
        beast_type: input.beast_type,
        level: input.level,
        health: input.health,
        pos_x: input.pos_x,
        pos_y: input.pos_y,
        attack_counter: 0,
        crit_chance: constants::DEFAULT_CRIT_CHANCE,
        range: constants::get_range(input.tier),
    }
}

/// Build monster queue from BeastInput array.
fn build_queue(beasts: Span<BeastInput>) -> Array<QueueEntry> {
    let mut queue: Array<QueueEntry> = array![];
    let mut i: u32 = 0;
    while i < beasts.len() {
        let b = *beasts.at(i);
        let is_swarm = b.tier == 3;
        queue
            .append(
                QueueEntry {
                    id: i.try_into().unwrap(),
                    name: b.name,
                    tier: b.tier,
                    beast_type: b.beast_type,
                    level: b.level,
                    health: b.health,
                    is_swarm,
                },
            );
        i += 1;
    };
    queue
}

/// Spawn a monster from the queue.
fn spawn_monster(
    ref state: SimulationState,
    ref monsters: Array<Monster>,
    ref queue_index: u32,
    queue: Span<QueueEntry>,
    start_x: u8,
    start_y: u8,
    ref next_monster_id: u8,
) {
    if queue_index >= queue.len() {
        return;
    }

    let entry = *queue.at(queue_index);
    queue_index += 1;

    if entry.is_swarm {
        // T3: spawn 4 copies with ceil(health/5) each
        let individual_health: u32 = math::ceil_div(entry.health, constants::SWARM_HEALTH_DIVISOR);
        let mut i: u8 = 0;
        while i < constants::SWARM_COUNT {
            let monster = Monster {
                id: next_monster_id,
                tier: entry.tier,
                beast_type: entry.beast_type,
                level: entry.level,
                health: individual_health.into(),
                max_health: individual_health,
                pos_x: start_x,
                pos_y: start_y,
                last_x: 0,
                last_y: 0,
                has_last_tile: false,
                alive: true,
                freeze_ticks: 0,
                shield: 0,
                spawn_tick: state.current_tick,
            };
            monsters.append(monster);
            next_monster_id += 1;
            i += 1;
        };
    } else {
        let shield = if entry.tier == 5 {
            math::ceil_div(entry.health * constants::SHIELD_HEALTH_PCT, 100)
        } else {
            0
        };

        let monster = Monster {
            id: next_monster_id,
            tier: entry.tier,
            beast_type: entry.beast_type,
            level: entry.level,
            health: entry.health.into(),
            max_health: entry.health,
            pos_x: start_x,
            pos_y: start_y,
            last_x: 0,
            last_y: 0,
            has_last_tile: false,
            alive: true,
            freeze_ticks: 0,
            shield,
            spawn_tick: state.current_tick,
        };
        monsters.append(monster);
        next_monster_id += 1;
    }
}

/// Check if a monster can move this tick.
fn can_move(monster: Monster, current_tick: u16, should_teleport: bool) -> bool {
    if monster.tier == 4 {
        return should_teleport;
    }
    if monster.freeze_ticks > 0 {
        return false;
    }
    let step_ticks: u16 = constants::get_step_ticks(monster.tier).into();
    let ticks_since_spawn = current_tick - monster.spawn_tick;
    (ticks_since_spawn % step_ticks) == 0
}

/// Move a single monster along the path.
fn move_monster(
    ref monster: Monster,
    ref state: SimulationState,
    path_tiles: Span<Tile>,
    end_x: u8,
    end_y: u8,
) {
    if !monster.alive {
        return;
    }

    // Handle freeze tick decrement
    if monster.freeze_ticks > 0 {
        monster.freeze_ticks -= 1;
        return;
    }

    // Check T4 move chance
    let should_move_t4 = if monster.tier == 4 {
        rng::rng_chance(ref state.rng_state, constants::T4_MOVE_CHANCE_PCT)
    } else {
        false
    };

    if !can_move(monster, state.current_tick, should_move_t4) {
        return;
    }

    // Determine number of move tiles (T4 teleport check)
    let mut move_tiles: u8 = 1;
    if monster.tier == 4 {
        if rng::rng_chance(ref state.rng_state, constants::T4_TELEPORT_CHANCE_PCT) {
            move_tiles = constants::T4_TELEPORT_TILES;
        }
    }

    let mut step: u8 = 0;
    while step < move_tiles {
        if !monster.alive {
            break;
        }

        let cx = monster.pos_x;
        let cy = monster.pos_y;

        let all_neighbors = get_adjacent_path_tiles(cx, cy, path_tiles);

        // Filter out last tile (backtrack prevention)
        let mut neighbors: Array<Tile> = array![];
        if monster.has_last_tile {
            let lx = monster.last_x;
            let ly = monster.last_y;
            let mut i: u32 = 0;
            while i < all_neighbors.len() {
                let n = *all_neighbors.at(i);
                if !(n.x == lx && n.y == ly) {
                    neighbors.append(n);
                }
                i += 1;
            };
            // If no non-backtrack neighbors, allow backtrack
            if neighbors.len() == 0 {
                neighbors.append(Tile { x: lx, y: ly });
            }
        } else {
            let mut i: u32 = 0;
            while i < all_neighbors.len() {
                neighbors.append(*all_neighbors.at(i));
                i += 1;
            };
        }

        if neighbors.len() == 0 {
            // No neighbors at all — escaped
            monster_escaped(ref monster, ref state);
            break;
        }

        // Pick random neighbor
        let idx = rng::rng_int(ref state.rng_state, neighbors.len());
        let next = *neighbors.at(idx);

        // Update position
        monster.last_x = cx;
        monster.last_y = cy;
        monster.has_last_tile = true;
        monster.pos_x = next.x;
        monster.pos_y = next.y;

        // Check end tile
        if is_end_tile(next.x, next.y, end_x, end_y) {
            monster_escaped(ref monster, ref state);
            break;
        }

        step += 1;
    };
}

/// Handle monster escape.
fn monster_escaped(ref monster: Monster, ref state: SimulationState) {
    monster.alive = false;
    state.monsters_escaped += 1;
}

/// Apply damage to a monster (handles T5 shield absorption per canonical .js).
fn apply_damage(ref monster: Monster, damage: u32, ref state: SimulationState) {
    let mut actual_damage = damage;

    // T5 shield: absorbs ALL damage, remaining -> 0
    if monster.tier == 5 && monster.shield > 0 {
        if actual_damage >= monster.shield {
            monster.shield = 0;
            actual_damage = 0; // shield absorbs ALL, remaining damage zeroed
        } else {
            monster.shield -= actual_damage;
            actual_damage = 0;
        }
    }

    monster.health -= actual_damage.into();
    if monster.health <= 0 {
        monster.alive = false;
        state.monsters_killed += 1;
    }
}

/// Get unique tiles that have alive monsters in range of tower.
/// Returns sorted array of (tile, monster_indices).
fn get_tiles_with_monsters_in_range(
    tower: Tower, monsters: Span<Monster>,
) -> Array<Tile> {
    let mut tiles: Array<Tile> = array![];
    let mut i: u32 = 0;
    while i < monsters.len() {
        let m = *monsters.at(i);
        if m.alive {
            let in_range = if tower.range == 0 {
                true // global
            } else {
                math::within_manhattan(tower.pos_x, tower.pos_y, m.pos_x, m.pos_y, tower.range)
            };
            if in_range {
                // Add tile if not already present
                let mut found = false;
                let mut j: u32 = 0;
                while j < tiles.len() {
                    let t = *tiles.at(j);
                    if t.x == m.pos_x && t.y == m.pos_y {
                        found = true;
                        break;
                    }
                    j += 1;
                };
                if !found {
                    tiles.append(Tile { x: m.pos_x, y: m.pos_y });
                }
            }
        }
        i += 1;
    };
    sort_tiles(tiles)
}

/// Get all alive monsters at a specific tile.
fn get_monsters_at_tile(monsters: Span<Monster>, x: u8, y: u8) -> Array<u32> {
    let mut indices: Array<u32> = array![];
    let mut i: u32 = 0;
    while i < monsters.len() {
        let m = *monsters.at(i);
        if m.alive && m.pos_x == x && m.pos_y == y {
            indices.append(i);
        }
        i += 1;
    };
    indices
}

/// Get all alive monsters in range.
fn get_monsters_in_range(tower: Tower, monsters: Span<Monster>) -> Array<u32> {
    let mut indices: Array<u32> = array![];
    let mut i: u32 = 0;
    while i < monsters.len() {
        let m = *monsters.at(i);
        if m.alive {
            let in_range = if tower.range == 0 {
                true
            } else {
                math::within_manhattan(tower.pos_x, tower.pos_y, m.pos_x, m.pos_y, tower.range)
            };
            if in_range {
                indices.append(i);
            }
        }
        i += 1;
    };
    indices
}

/// Get surrounding tiles for AoE (3x3 centered on target, excluding center).
fn get_surrounding_tiles(
    x: u8, y: u8, range: u8, width: u8, height: u8,
) -> Array<Tile> {
    let mut tiles: Array<Tile> = array![];
    let r: i16 = range.into();
    let mut dx: i16 = -r;
    while dx <= r {
        let mut dy: i16 = -r;
        while dy <= r {
            if !(dx == 0 && dy == 0) {
                let tx: i16 = x.into() + dx;
                let ty: i16 = y.into() + dy;
                if tx >= 0 && tx < width.into() && ty >= 0 && ty < height.into() {
                    tiles.append(Tile { x: tx.try_into().unwrap(), y: ty.try_into().unwrap() });
                }
            }
            dy += 1;
        };
        dx += 1;
    };
    tiles
}

// =============================================================================
// Tower attack implementations
// =============================================================================

/// T1: Freeze attack — targets random tile, freezes 1-all monsters.
fn tower_tier1_attack(
    tower: Tower,
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    is_crit: bool,
    crit_multiplier: u32,
) {
    let monsters_span = monsters.span();
    let tiles = get_tiles_with_monsters_in_range(tower, monsters_span);
    if tiles.len() == 0 {
        return;
    }

    // Pick random tile
    let tile_idx = rng::rng_int(ref state.rng_state, tiles.len());
    let target_tile = *tiles.at(tile_idx);

    // Get monsters on that tile
    let monster_indices = get_monsters_at_tile(monsters_span, target_tile.x, target_tile.y);
    if monster_indices.len() == 0 {
        return;
    }

    // Determine freeze count by level thresholds
    let freeze_count: u32 = if tower.level >= 100 {
        monster_indices.len()
    } else if tower.level >= 60 {
        3
    } else if tower.level >= 30 {
        2
    } else {
        1
    };

    let freeze_duration: u32 = 1 * crit_multiplier;

    // Shuffle monster indices for random selection
    let mut idx_as_u8: Array<u8> = array![];
    let mut i: u32 = 0;
    while i < monster_indices.len() {
        idx_as_u8.append(i.try_into().unwrap());
        i += 1;
    };
    let shuffled = rng::rng_shuffle(ref state.rng_state, idx_as_u8.span());

    // Apply freeze
    let count = if freeze_count < shuffled.len() {
        freeze_count
    } else {
        shuffled.len()
    };

    // Rebuild monsters with freeze applied
    let mut new_monsters: Array<Monster> = array![];
    let mut applied: Array<u32> = array![]; // indices that got frozen

    let mut si: u32 = 0;
    while si < count {
        let shuffled_pos: u8 = *shuffled.at(si);
        let actual_idx: u32 = *monster_indices.at(shuffled_pos.into());
        let m = *monsters_span.at(actual_idx);

        // Skip T5 monsters
        if m.tier != 5 {
            let (num, den) = math::get_type_multiplier(tower.beast_type, m.beast_type);
            let effective_freeze = math::apply_multiplier(freeze_duration, num, den);
            let freeze_u8: u8 = effective_freeze.try_into().unwrap();
            applied.append(actual_idx);
            // Store the freeze amount to apply later (index -> freeze)
            let _ = freeze_u8; // used below in rebuild
        }
        si += 1;
    };

    // Actually rebuild with freezes applied
    let mut mi: u32 = 0;
    while mi < monsters_span.len() {
        let mut m = *monsters_span.at(mi);
        // Check if this monster should be frozen
        let mut should_freeze = false;
        let mut freeze_amount: u8 = 0;
        // Re-check which shuffled entries correspond to this monster index
        let mut si2: u32 = 0;
        while si2 < count {
            let shuffled_pos: u8 = *shuffled.at(si2);
            let actual_idx: u32 = *monster_indices.at(shuffled_pos.into());
            if actual_idx == mi && m.tier != 5 {
                let (num, den) = math::get_type_multiplier(tower.beast_type, m.beast_type);
                let effective_freeze = math::apply_multiplier(freeze_duration, num, den);
                freeze_amount = effective_freeze.try_into().unwrap();
                should_freeze = true;
                break;
            }
            si2 += 1;
        };

        if should_freeze {
            m.freeze_ticks += freeze_amount;
        }
        new_monsters.append(m);
        mi += 1;
    };

    monsters = new_monsters;
}

/// T2: AoE burst — 3x3 area centered on random target tile.
fn tower_tier2_attack(
    tower: Tower,
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    is_crit: bool,
    crit_multiplier: u32,
    grid_width: u8,
    grid_height: u8,
) {
    let monsters_span = monsters.span();
    let tiles = get_tiles_with_monsters_in_range(tower, monsters_span);
    if tiles.len() == 0 {
        return;
    }

    // Pick random target tile
    let tile_idx = rng::rng_int(ref state.rng_state, tiles.len());
    let target_tile = *tiles.at(tile_idx);

    // Base damage: ceil(level * critMultiplier / 10)
    let base_damage = math::ceil_div(tower.level.into() * crit_multiplier, 10);

    // Get 3x3 surrounding tiles + center
    let mut aoe_tiles = get_surrounding_tiles(
        target_tile.x, target_tile.y, 1, grid_width, grid_height,
    );
    aoe_tiles.append(target_tile); // include center

    // Apply damage to all monsters on AoE tiles
    let mut new_monsters: Array<Monster> = array![];
    let mut mi: u32 = 0;
    while mi < monsters_span.len() {
        let mut m = *monsters_span.at(mi);
        if m.alive {
            // Check if monster is on any AoE tile
            let mut on_aoe = false;
            let mut ti: u32 = 0;
            while ti < aoe_tiles.len() {
                let aoe_t = *aoe_tiles.at(ti);
                if m.pos_x == aoe_t.x && m.pos_y == aoe_t.y {
                    on_aoe = true;
                    break;
                }
                ti += 1;
            };
            if on_aoe {
                let (num, den) = math::get_type_multiplier(tower.beast_type, m.beast_type);
                let effective_damage = math::apply_multiplier(base_damage, num, den);
                apply_damage(ref m, effective_damage, ref state);
            }
        }
        new_monsters.append(m);
        mi += 1;
    };

    monsters = new_monsters;
}

/// T3: Global attack — hits all alive monsters.
fn tower_tier3_attack(
    tower: Tower,
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    is_crit: bool,
    crit_multiplier: u32,
) {
    // Base damage: ceil(level * critMultiplier / 100)
    let base_damage = math::ceil_div(tower.level.into() * crit_multiplier, 100);

    let monsters_span = monsters.span();
    let mut new_monsters: Array<Monster> = array![];
    let mut i: u32 = 0;
    while i < monsters_span.len() {
        let mut m = *monsters_span.at(i);
        if m.alive {
            let (num, den) = math::get_type_multiplier(tower.beast_type, m.beast_type);
            let effective_damage = math::apply_multiplier(base_damage, num, den);
            apply_damage(ref m, effective_damage, ref state);
        }
        new_monsters.append(m);
        i += 1;
    };

    monsters = new_monsters;
}

/// T4: Double-shot — fires twice, targets rightmost tile each time.
fn tower_tier4_attack(
    tower: Tower,
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    is_crit: bool,
    crit_multiplier: u32,
) {
    let mut shot: u8 = 0;
    while shot < 2 {
        let monsters_span = monsters.span();
        let tiles = get_tiles_with_monsters_in_range(tower, monsters_span);
        if tiles.len() == 0 {
            break;
        }

        // Find rightmost tile (highest x)
        let mut rightmost_idx: u32 = 0;
        let mut rightmost_x: u8 = 0;
        let mut ti: u32 = 0;
        while ti < tiles.len() {
            let t = *tiles.at(ti);
            if ti == 0 || t.x > rightmost_x {
                rightmost_x = t.x;
                rightmost_idx = ti;
            }
            ti += 1;
        };

        let target_tile = *tiles.at(rightmost_idx);
        let monster_indices = get_monsters_at_tile(monsters_span, target_tile.x, target_tile.y);
        if monster_indices.len() == 0 {
            break;
        }

        // Pick random monster on rightmost tile
        let mi = rng::rng_int(ref state.rng_state, monster_indices.len());
        let target_idx = *monster_indices.at(mi);

        // Damage = level * critMultiplier (NOT divided)
        let base_damage: u32 = tower.level.into() * crit_multiplier;

        let target = *monsters_span.at(target_idx);
        let (num, den) = math::get_type_multiplier(tower.beast_type, target.beast_type);
        let effective_damage = math::apply_multiplier(base_damage, num, den);

        // Apply damage - rebuild monster array
        let mut new_monsters: Array<Monster> = array![];
        let mut j: u32 = 0;
        while j < monsters_span.len() {
            let mut m = *monsters_span.at(j);
            if j == target_idx {
                apply_damage(ref m, effective_damage, ref state);
            }
            new_monsters.append(m);
            j += 1;
        };
        monsters = new_monsters;

        shot += 1;
    };
}

/// T5: Tank-buster — targets highest HP monster in range 3.
fn tower_tier5_attack(
    tower: Tower,
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    is_crit: bool,
    crit_multiplier: u32,
) {
    let monsters_span = monsters.span();
    let in_range = get_monsters_in_range(tower, monsters_span);
    if in_range.len() == 0 {
        return;
    }

    // Find monster with highest (health + shield)
    let mut max_hp: i64 = -1;
    let mut target_idx: u32 = 0;
    let mut i: u32 = 0;
    while i < in_range.len() {
        let idx = *in_range.at(i);
        let m = *monsters_span.at(idx);
        let total_hp: i64 = m.health + m.shield.into();
        if total_hp > max_hp {
            max_hp = total_hp;
            target_idx = idx;
        }
        i += 1;
    };

    // Damage = level * critMultiplier
    let base_damage: u32 = tower.level.into() * crit_multiplier;
    let target = *monsters_span.at(target_idx);
    let (num, den) = math::get_type_multiplier(tower.beast_type, target.beast_type);
    let effective_damage = math::apply_multiplier(base_damage, num, den);

    // Apply damage - rebuild
    let mut new_monsters: Array<Monster> = array![];
    let mut j: u32 = 0;
    while j < monsters_span.len() {
        let mut m = *monsters_span.at(j);
        if j == target_idx {
            apply_damage(ref m, effective_damage, ref state);
        }
        new_monsters.append(m);
        j += 1;
    };

    monsters = new_monsters;
}

/// Dispatch tower attack based on tier.
fn tower_attack(
    tower: Tower,
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    grid_width: u8,
    grid_height: u8,
) {
    let is_crit = rng::rng_chance(ref state.rng_state, tower.crit_chance);
    let crit_multiplier: u32 = if is_crit {
        2
    } else {
        1
    };

    if tower.tier == 1 {
        tower_tier1_attack(tower, ref monsters, ref state, is_crit, crit_multiplier);
    } else if tower.tier == 2 {
        tower_tier2_attack(
            tower, ref monsters, ref state, is_crit, crit_multiplier, grid_width, grid_height,
        );
    } else if tower.tier == 3 {
        tower_tier3_attack(tower, ref monsters, ref state, is_crit, crit_multiplier);
    } else if tower.tier == 4 {
        tower_tier4_attack(tower, ref monsters, ref state, is_crit, crit_multiplier);
    } else if tower.tier == 5 {
        tower_tier5_attack(tower, ref monsters, ref state, is_crit, crit_multiplier);
    }
}

/// Process all tower attacks for a tick.
fn process_tower_attacks(
    ref towers: Array<Tower>,
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    grid_width: u8,
    grid_height: u8,
) {
    let towers_span = towers.span();
    let mut new_towers: Array<Tower> = array![];
    let mut i: u32 = 0;
    while i < towers_span.len() {
        let mut t = *towers_span.at(i);
        if t.tier == 4 {
            // T4 always fires
            tower_attack(t, ref monsters, ref state, grid_width, grid_height);
        } else {
            t.attack_counter += 1;
            let attack_speed = constants::get_attack_speed(t.tier);
            if t.attack_counter >= attack_speed {
                t.attack_counter = 0;
                tower_attack(t, ref monsters, ref state, grid_width, grid_height);
            }
        }
        new_towers.append(t);
        i += 1;
    };
    towers = new_towers;
}

/// Process all monster movement for a tick.
fn process_monster_movement(
    ref monsters: Array<Monster>,
    ref state: SimulationState,
    path_tiles: Span<Tile>,
    end_x: u8,
    end_y: u8,
) {
    let monsters_span = monsters.span();
    let mut new_monsters: Array<Monster> = array![];
    let mut i: u32 = 0;
    while i < monsters_span.len() {
        let mut m = *monsters_span.at(i);
        if m.alive {
            move_monster(ref m, ref state, path_tiles, end_x, end_y);
        }
        new_monsters.append(m);
        i += 1;
    };
    monsters = new_monsters;
}

/// Remove dead monsters from array.
fn cleanup_dead_monsters(ref monsters: Array<Monster>) {
    let span = monsters.span();
    let mut alive: Array<Monster> = array![];
    let mut i: u32 = 0;
    while i < span.len() {
        let m = *span.at(i);
        if m.alive {
            alive.append(m);
        }
        i += 1;
    };
    monsters = alive;
}

/// Check win condition: queue empty AND all monsters dead/escaped.
fn check_win_condition(
    ref state: SimulationState, queue_index: u32, queue_len: u32, monsters: Span<Monster>,
) {
    if queue_index < queue_len {
        return; // still entries in queue
    }

    let mut all_done = true;
    let mut i: u32 = 0;
    while i < monsters.len() {
        if (*monsters.at(i)).alive {
            all_done = false;
            break;
        }
        i += 1;
    };

    if all_done {
        state.finished = true;
        determine_winner(ref state);
    }
}

/// Determine winner: killed > escaped → defender, escaped > killed → attacker, else → draw.
fn determine_winner(ref state: SimulationState) {
    if state.monsters_killed > state.monsters_escaped {
        state.winner = 1; // defender
    } else if state.monsters_escaped > state.monsters_killed {
        state.winner = 2; // attacker
    } else {
        state.winner = 0; // draw
    }
}

/// Execute one tick of the simulation.
fn tick(
    ref state: SimulationState,
    ref towers: Array<Tower>,
    ref monsters: Array<Monster>,
    ref queue_index: u32,
    queue: Span<QueueEntry>,
    path_tiles: Span<Tile>,
    start_x: u8,
    start_y: u8,
    end_x: u8,
    end_y: u8,
    grid_width: u8,
    grid_height: u8,
    ref next_monster_id: u8,
) {
    if state.finished {
        return;
    }
    state.current_tick += 1;

    // 1. Spawn
    spawn_monster(ref state, ref monsters, ref queue_index, queue, start_x, start_y, ref next_monster_id);

    // 2. Tower attacks
    process_tower_attacks(ref towers, ref monsters, ref state, grid_width, grid_height);

    // 3. Monster movement
    process_monster_movement(ref monsters, ref state, path_tiles, end_x, end_y);

    // 4. Cleanup
    cleanup_dead_monsters(ref monsters);

    // 5. Win check
    check_win_condition(ref state, queue_index, queue.len(), monsters.span());
}

/// Run a full simulation with given parameters (pure function, no world access).
pub fn execute_simulation(
    seed: u32,
    tower_inputs: Span<TowerInput>,
    beast_inputs: Span<BeastInput>,
    path_tiles: Span<Tile>,
    start_x: u8,
    start_y: u8,
    end_x: u8,
    end_y: u8,
    grid_width: u8,
    grid_height: u8,
    max_ticks: u16,
) -> SimulationResult {
    // Build towers
    let mut towers: Array<Tower> = array![];
    let mut i: u32 = 0;
    while i < tower_inputs.len() {
        towers.append(build_tower(*tower_inputs.at(i), i.try_into().unwrap()));
        i += 1;
    };

    // Build queue
    let queue = build_queue(beast_inputs);
    let queue_span = queue.span();
    let mut queue_index: u32 = 0;

    // Build monsters (empty at start)
    let mut monsters: Array<Monster> = array![];
    let mut next_monster_id: u8 = 0;

    // Init state
    let mut state = SimulationState {
        rng_state: seed,
        current_tick: 0,
        monsters_escaped: 0,
        monsters_killed: 0,
        finished: false,
        winner: 0,
    };

    // Run tick loop
    while !state.finished && state.current_tick < max_ticks {
        tick(
            ref state,
            ref towers,
            ref monsters,
            ref queue_index,
            queue_span,
            path_tiles,
            start_x,
            start_y,
            end_x,
            end_y,
            grid_width,
            grid_height,
            ref next_monster_id,
        );
    };

    // Force-determine winner on timeout
    if !state.finished {
        state.finished = true;
        determine_winner(ref state);
    }

    SimulationResult {
        winner: state.winner,
        monsters_killed: state.monsters_killed,
        monsters_escaped: state.monsters_escaped,
        total_ticks: state.current_tick,
    }
}

// =============================================================================
// Dojo Contract
// =============================================================================

#[dojo::contract]
pub mod simulation {
    use dojo::model::ModelStorage;
    use beast_td::models::beast::{TowerInput, BeastInput, SimulationResult};
    use beast_td::models::grid::{GameGrid, GridPathTile};
    use beast_td::models::simulation::Tile;
    use super::{ISimulation, execute_simulation};

    #[abi(embed_v0)]
    impl SimulationImpl of ISimulation<ContractState> {
        fn run_simulation(
            ref self: ContractState,
            seed: u32,
            grid_id: u32,
            towers: Array<TowerInput>,
            beasts: Array<BeastInput>,
            max_ticks: u16,
        ) -> SimulationResult {
            let world = self.world_default();

            // Read grid from world
            let grid: GameGrid = world.read_model(grid_id);
            assert(grid.width > 0, beast_td::utils::constants::errors::INVALID_GRID);

            // Read path tiles
            let mut path_tiles: Array<Tile> = array![];
            let mut i: u8 = 0;
            while i < grid.path_count {
                let pt: GridPathTile = world.read_model((grid_id, i));
                path_tiles.append(Tile { x: pt.x, y: pt.y });
                i += 1;
            };

            execute_simulation(
                seed,
                towers.span(),
                beasts.span(),
                path_tiles.span(),
                grid.start_x,
                grid.start_y,
                grid.end_x,
                grid.end_y,
                grid.width,
                grid.height,
                max_ticks,
            )
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"beast_td")
        }
    }
}
