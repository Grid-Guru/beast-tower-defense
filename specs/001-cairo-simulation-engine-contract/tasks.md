# Tasks: Cairo Simulation Engine Contract

**Input**: Design documents from `/specs/001-cairo-simulation-engine-contract/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included — the spec requires deterministic regression tests against the JS reference engine (SC-001 through SC-007), and the plan mandates test-first development.

**Organization**: Tasks grouped by user story. US1 (simulation engine) is the MVP.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- All file paths relative to `contracts/` directory

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the Dojo project, directory structure, and build configuration.

- [ ] T001 Initialize Dojo project: create `contracts/Scarb.toml` with `beast_td` package name, Dojo dependency, and `[[target.dojo]]`
- [ ] T002 Create `contracts/dojo_dev.toml` with world name `Beast Tower Defense`, namespace `beast_td`, local RPC, and writer permissions for all three system contracts
- [ ] T003 Create `contracts/katana.toml` with default Katana sequencer config
- [ ] T004 Create directory structure: `contracts/src/{models,systems,utils}` and `contracts/tests/`
- [ ] T005 Create `contracts/src/lib.cairo` with module declarations for all submodules: `models`, `systems`, `utils`, `events`

**Checkpoint**: `sozo build` should succeed with empty modules (no compilation errors).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utilities, constants, enums, and shared models that ALL user stories depend on. Must complete before any story begins.

**CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T006 [P] Define all game constants in `contracts/src/utils/constants.cairo`: tower tier configs (attack_speed, range per tier), monster tier configs (step_ticks per tier), game limits (MAX_TICKS, MAX_TOWERS, MAX_BEASTS, MAX_GRID_SIZE, MAX_PATH_LENGTH), combat params (DEFAULT_CRIT_CHANCE, SWARM_COUNT, SHIELD_HEALTH_PCT, T4 move/teleport params), economy (WAGER_FEE_PCT)
- [ ] T007 [P] Define enums and input/output structs in `contracts/src/models/beast.cairo`: BeastType enum (Hunter, Magic, Brute), TowerInput struct, BeastInput struct, SimulationResult struct; derive Copy, Drop, Serde on all
- [ ] T008 [P] Implement Mulberry32 seeded PRNG in `contracts/src/utils/rng.cairo`: `rng_next(ref state: u32) -> u32` using wrapping add/mul, `rng_int(ref state: u32, max: u32) -> u32` via modulo, `rng_chance(ref state: u32, pct: u8) -> bool` for percentage checks, `rng_shuffle(ref state: u32, ref arr: Array<T>)` for Fisher-Yates shuffle. Port the exact Mulberry32 algorithm from SimulationEngine.js lines 38-45
- [ ] T009 [P] Implement math helpers in `contracts/src/utils/math.cairo`: `ceil_div(a: u32, b: u32) -> u32` for Math.ceil equivalent, `get_type_multiplier(attacker_type: u8, defender_type: u8) -> (u32, u32)` returning (numerator, denominator) for the type triangle, `apply_multiplier(value: u32, num: u32, den: u32) -> u32` applying ceil((value * num) / den), `within_manhattan(x1: u8, y1: u8, x2: u8, y2: u8, range: u8) -> bool`
- [ ] T010 [P] Define GameGrid Dojo models in `contracts/src/models/grid.cairo`: `GameGrid` model keyed by grid_id with width/height/start/end/counts, `GridPathTile` model keyed by (grid_id, index) with x/y, `GridBlockedTile` model keyed by (grid_id, index) with x/y. Derive Copy, Drop, Serde with `#[dojo::model]`
- [ ] T011 [P] Define simulation runtime structs in `contracts/src/models/simulation.cairo`: `Tower` struct (id, tier, beast_type, level, health, pos_x, pos_y, attack_counter, crit_chance, range), `Monster` struct (id, tier, beast_type, level, health, max_health, pos_x, pos_y, last_x, last_y, has_last_tile, alive, freeze_ticks, shield, spawn_tick), `SimulationState` struct (rng_state, current_tick, monsters_escaped, monsters_killed, finished, winner). These are NOT Dojo models — just plain Cairo structs
- [ ] T012 [P] Define all Dojo events in `contracts/src/events.cairo`: SpawnEvent, DamageEvent, FreezeEvent, KillEvent, EscapeEvent, GameEndEvent, MoveEvent, MatchCreated, MatchJoined, MatchResolved, MatchCancelled. Each with `#[dojo::event]` and appropriate `#[key]` fields per the contracts/events.cairo design artifact

### Foundational Tests

- [ ] T013 [P] Write PRNG determinism tests in `contracts/tests/test_rng.cairo`: test that `rng_next` with seed 12345 produces the exact same sequence as JS Mulberry32 with seed 12345 (capture first 10 values from JS engine as expected). Test `rng_int` distribution and `rng_chance` thresholds
- [ ] T014 [P] Write type chart tests in `contracts/tests/test_type_chart.cairo`: test all 9 type combinations (hunter/magic/brute × hunter/magic/brute) return correct (num, den) pairs. Test `apply_multiplier` with ceil behavior matching `Math.ceil(damage * multiplier)` from JS. Test `within_manhattan` with known coordinate pairs

**Checkpoint**: `sozo build` compiles successfully. `sozo test` passes all foundational tests. RNG output matches JS reference values.

---

## Phase 3: User Story 1 — Run a Deterministic Simulation On-Chain (Priority: P1) MVP

**Goal**: Execute the full tick-based simulation loop on-chain, producing identical results to SimulationEngine.js for any given (config, seed) pair.

**Independent Test**: Call `run_simulation` with a known config + seed, assert result matches JS engine output for winner, monstersKilled, monstersEscaped, totalTicks.

### Tests for User Story 1

> **Write these tests FIRST. They MUST FAIL before implementation.**

- [ ] T015 [P] [US1] Write tower tier 1 (freeze) tests in `contracts/tests/test_tower_tiers.cairo`: test freeze targets correct count based on level thresholds (<30=1, 30-59=2, 60-99=3, 100+=all), test T5 monsters are skipped, test crit doubles freeze duration, test type multiplier applied with ceil, test freeze accumulates on monster
- [ ] T016 [P] [US1] Write tower tier 2 (AoE) tests in `contracts/tests/test_tower_tiers.cairo`: test 3x3 area damage centered on random target tile, test `ceil(level/10)` base damage, test type multiplier applied per monster, test crit doubles damage
- [ ] T017 [P] [US1] Write tower tier 3 (global) tests in `contracts/tests/test_tower_tiers.cairo`: test hits all alive monsters regardless of position, test `ceil(level/100)` base damage, test type multiplier per monster
- [ ] T018 [P] [US1] Write tower tier 4 (double-shot) tests in `contracts/tests/test_tower_tiers.cairo`: test fires twice per tick, test targets rightmost tile, test `level` base damage (not divided), test always ready (no attack counter)
- [ ] T019 [P] [US1] Write tower tier 5 (tank-buster) tests in `contracts/tests/test_tower_tiers.cairo`: test targets highest HP monster (health + shield), test range 3, test `level` base damage
- [ ] T020 [P] [US1] Write monster tier behavior tests in `contracts/tests/test_monster_tiers.cairo`: T1 moves every 4 ticks, T2 moves every tick, T3 spawns as 4 copies with ceil(health/5) each, T4 has 10% move chance and 10% teleport (2 tiles), T5 gets ceil(50% health) shield and moves every 3 ticks
- [ ] T021 [P] [US1] Write shield absorption tests in `contracts/tests/test_monster_tiers.cairo`: test shield absorbs damage and zeroes remaining (per .js canonical — NOT pass-through), test shield depletes correctly over multiple hits
- [ ] T022 [P] [US1] Write full simulation regression tests in `contracts/tests/test_simulation.cairo`: run SimulationEngine.js with 3+ different configs/seeds, capture exact outputs (winner, killed, escaped, ticks), assert Cairo produces identical results

### Implementation for User Story 1

- [ ] T023 [US1] Implement grid utility functions as free functions in `contracts/src/systems/simulation.cairo`: `get_adjacent_path_tiles(x, y, ref path_tiles) -> Array<(u8, u8)>` returning 4-directional neighbors that are path tiles, `is_end_tile(x, y, end_x, end_y) -> bool`, `get_surrounding_tiles(x, y, range, width, height) -> Array<(u8, u8)>` for AoE, `sort_tile_keys(ref tiles) -> Array<(u8, u8)>` for deterministic tile ordering
- [ ] T024 [US1] Implement monster spawning in `contracts/src/systems/simulation.cairo`: `spawn_monster(ref state, ref monsters, ref queue, start_x, start_y)` — dequeue one entry, create Monster struct. For T3 (isSwarm): spawn 4 copies with `ceil(health/5)`, mark split=true. For T5: set shield = `ceil(health * 50 / 100)`. Emit SpawnEvent per monster spawned
- [ ] T025 [US1] Implement monster movement in `contracts/src/systems/simulation.cairo`: `move_monster(ref monster, ref state, ref path_tiles, end_x, end_y)` — handle freeze tick decrement, `can_move` check per tier (T4: rng 10% chance), get neighbors excluding last_tile, random selection, update position. T4 teleport: 10% chance for 2-tile move. Emit MoveEvent. Handle escape at end tile with EscapeEvent
- [ ] T026 [US1] Implement tower attack dispatch in `contracts/src/systems/simulation.cairo`: `tower_attack(ref tower, ref monsters, ref state)` — roll crit (20% base), dispatch to tier-specific function. Implement `get_monsters_in_range` using Manhattan distance, `get_tiles_with_monsters_in_range` returning tile→monsters map, `get_monsters_at_tile`
- [ ] T027 [US1] Implement T1 freeze attack in `contracts/src/systems/simulation.cairo`: `tower_tier1_attack(ref tower, ref monsters, ref state, is_crit, crit_mult)` — pick random tile in range, determine freeze count by level thresholds, shuffle monsters on tile, apply freeze with type multiplier and ceil, skip T5 monsters. Emit FreezeEvent
- [ ] T028 [US1] Implement T2 AoE attack in `contracts/src/systems/simulation.cairo`: `tower_tier2_attack(...)` — pick random target tile, calc `ceil(level/10) * crit_mult` base damage, get 3x3 surrounding tiles, apply damage with type multiplier to all monsters in area. Emit DamageEvent per hit
- [ ] T029 [US1] Implement T3 global attack in `contracts/src/systems/simulation.cairo`: `tower_tier3_attack(...)` — calc `ceil(level/100) * crit_mult` base damage, iterate all alive monsters, apply damage with type multiplier. Emit DamageEvent per hit
- [ ] T030 [US1] Implement T4 double-shot attack in `contracts/src/systems/simulation.cairo`: `tower_tier4_attack(...)` — loop 2 shots, find rightmost tile with monsters, pick random target on that tile, apply `level * crit_mult` damage with type multiplier. Emit DamageEvent per hit
- [ ] T031 [US1] Implement T5 tank-buster attack in `contracts/src/systems/simulation.cairo`: `tower_tier5_attack(...)` — find monster with highest (health + shield) in range 3, apply `level * crit_mult` damage with type multiplier. Emit DamageEvent
- [ ] T032 [US1] Implement `apply_damage` in `contracts/src/systems/simulation.cairo`: absorb with shield first (T5 shield absorbs ALL, remaining damage = 0 per canonical .js), then subtract from health. If health <= 0: mark dead, increment monsters_killed, emit KillEvent
- [ ] T033 [US1] Implement `process_tower_attacks` in `contracts/src/systems/simulation.cairo`: iterate towers, T4 always fires, others increment attack_counter and fire when counter >= attack_speed then reset counter
- [ ] T034 [US1] Implement `process_monster_movement` in `contracts/src/systems/simulation.cairo`: iterate alive monsters, call move_monster for each
- [ ] T035 [US1] Implement `cleanup_dead_monsters` in `contracts/src/systems/simulation.cairo`: filter monsters array to only alive entries
- [ ] T036 [US1] Implement `check_win_condition` and `determine_winner` in `contracts/src/systems/simulation.cairo`: check queue empty AND all monsters dead/escaped. Winner: killed > escaped → defender, escaped > killed → attacker, else → draw. Emit GameEndEvent
- [ ] T037 [US1] Implement tick loop and `run_simulation` in `contracts/src/systems/simulation.cairo`: `tick()` calls spawn→attacks→movement→cleanup→win_check in order. `run_simulation()` loops tick until finished or max_ticks, force-determines winner on timeout. Build Tower/Monster arrays from input, load grid path tiles from Dojo World, return SimulationResult
- [ ] T038 [US1] Create `#[dojo::contract] mod simulation` in `contracts/src/systems/simulation.cairo`: implement `ISimulation` trait with `run_simulation` function that reads GameGrid + path/blocked tiles from World, constructs runtime state, runs simulation loop, returns SimulationResult

### Generate JS Reference Test Data

- [ ] T039 [US1] Create test data generator script at repo root `scripts/generate_test_vectors.js`: run SimulationEngine.js with 3+ test configs (simple 1v1, multi-tower multi-beast, all-escape, all-kill, T3 swarm, T5 shield), capture exact RNG sequence (first 10 values for seed 12345), capture exact simulation outputs. Output as Cairo-compatible constants for test files

**Checkpoint**: `sozo test` passes all US1 tests. Simulation output matches JS reference engine for all test vectors. MVP is functional.

---

## Phase 4: User Story 2 — Create and Join a Match with Wager (Priority: P2)

**Goal**: Enable two players to create, join, and resolve a 1v1 match with wager escrow and 2-round execution.

**Independent Test**: Call `create_match` as P1, `join_match` as P2, verify both rounds execute, scores are correct, winner receives 95% of pot.

**Depends on**: US1 (simulation engine must work)

### Tests for User Story 2

- [ ] T040 [P] [US2] Write match lifecycle tests in `contracts/tests/test_match.cairo`: test create_match stores Match model with AwaitingOpponent status and player1 address, test wager is escrowed, test join_match transitions to Completed, test both rounds execute with correct role swapping (R1: P1 towers vs P2 beasts, R2: P2 towers vs P1 beasts), test winner determination from net scores, test payout distribution (95% winner / 5% fee), test draw refunds both players
- [ ] T041 [P] [US2] Write match error case tests in `contracts/tests/test_match.cairo`: test CANNOT_JOIN_OWN_MATCH, test MATCH_NOT_FOUND, test MATCH_NOT_AWAITING (join completed match), test cancel_match only by player1, test cancel refunds wager

### Implementation for User Story 2

- [ ] T042 [P] [US2] Define Match and MatchResult Dojo models in `contracts/src/models/match_state.cairo`: Match model keyed by match_id with player1/player2/grid_id/wager/status/seed/winner, MatchResult model keyed by match_id with per-round killed/escaped/ticks/winner and final_winner/net_scores, MatchStatus enum, PlayerSetup/PlayerTower/PlayerBeast models keyed by (match_id, player, index)
- [ ] T043 [US2] Implement `create_match` in `contracts/src/systems/match_actions.cairo`: validate grid exists, validate tower placements (not on path/blocked, within bounds, no duplicates), store Match with AwaitingOpponent status, store PlayerSetup + PlayerTower + PlayerBeast models for P1, escrow wager (transfer from caller to contract), emit MatchCreated event, return match_id
- [ ] T044 [US2] Implement `join_match` in `contracts/src/systems/match_actions.cairo`: validate match exists and is AwaitingOpponent, validate caller != player1, validate wager matches, validate P2's tower placements, store P2 setup, escrow P2 wager. Execute Round 1 (P1 towers vs P2 beasts with seed), execute Round 2 (P2 towers vs P1 beasts with seed+1). Calculate net scores, determine overall winner (or tiebreak by squad cost), store MatchResult, distribute pot (95/5), update Match status to Completed, emit MatchJoined + MatchResolved events, return MatchResultOutput
- [ ] T045 [US2] Implement `cancel_match` in `contracts/src/systems/match_actions.cairo`: validate caller is player1, match is AwaitingOpponent, refund wager, set status to Cancelled, emit MatchCancelled
- [ ] T046 [US2] Implement `get_match` view function in `contracts/src/systems/match_actions.cairo`: read Match model from World, return MatchView struct

**Checkpoint**: `sozo test` passes all US2 tests. Full match flow works end-to-end on Katana.

---

## Phase 5: User Story 3 — Squad Building with Budget Constraints (Priority: P3)

**Goal**: Validate squad compositions against a point budget to ensure competitive fairness.

**Independent Test**: Call `validate_towers` and `validate_beasts` with various compositions, verify over-budget squads are rejected.

**Depends on**: Phase 2 foundational models only. Can be developed in parallel with US1/US2.

### Tests for User Story 3

- [ ] T047 [P] [US3] Write squad validation tests in `contracts/tests/test_squad.cairo`: test `beast_cost(50, 100)` returns 150, test valid squad (within budget) passes, test over-budget squad reverts SQUAD_OVER_BUDGET, test empty squad reverts EMPTY_SQUAD, test invalid tier/type reverts, test tower position validation (on path, on blocked, out of bounds, duplicate positions)

### Implementation for User Story 3

- [ ] T048 [P] [US3] Implement `beast_cost` in `contracts/src/systems/squad.cairo`: `beast_cost(level: u16, health: u32) -> u32` returning `level.into() + health` (per design doc formula)
- [ ] T049 [US3] Implement `validate_towers` in `contracts/src/systems/squad.cairo`: check count <= MAX_TOWERS, each tower has valid tier (1-5) and type (1-3), level > 0, health > 0, position within grid bounds, not on path tile, not on blocked tile, no duplicate positions, total cost <= budget. Read grid data from Dojo World
- [ ] T050 [US3] Implement `validate_beasts` in `contracts/src/systems/squad.cairo`: check count <= MAX_BEASTS, each beast has valid tier and type, level > 0, health > 0, total cost <= budget
- [ ] T051 [US3] Create `#[dojo::contract] mod squad` in `contracts/src/systems/squad.cairo`: implement `ISquad` trait exposing `validate_towers`, `validate_beasts`, `beast_cost` as contract functions
- [ ] T052 [US3] Integrate budget validation into match_actions: in `create_match` and `join_match`, call squad validation before accepting setups. Reject with SQUAD_OVER_BUDGET if over budget

**Checkpoint**: `sozo test` passes all US3 tests. Budget validation prevents unfair squads.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, optimization, and deployment readiness.

- [ ] T053 Register at least one reference GameGrid in a deployment script or init function: define a playable map (e.g., 10x10 grid with a winding path), write GameGrid + GridPathTile + GridBlockedTile models to World
- [ ] T054 [P] Gas benchmarking: run a typical simulation (5 towers, 5 beasts, ~100 ticks) on Katana, capture step count, verify it stays within Starknet transaction limits (SC-005)
- [ ] T055 [P] Edge case hardening: test and handle maxTicks timeout (force-end + determine winner), empty monster queue, monsters with 0 health input, grid with single-tile path
- [ ] T056 Run full `sozo build && sozo test` to validate all tests pass, no compilation warnings
- [ ] T057 Validate quickstart.md instructions: follow the quickstart from scratch on a clean environment, verify build/test/deploy cycle works

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — BLOCKS US2 (match system needs simulation)
- **US2 (Phase 4)**: Depends on Phase 2 + US1 (calls simulation engine internally)
- **US3 (Phase 5)**: Depends on Phase 2 only — CAN run in parallel with US1
- **Polish (Phase 6)**: Depends on all stories being complete

### User Story Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational)
    │
    ├──────────────────┐
    ▼                  ▼
Phase 3 (US1)     Phase 5 (US3)
Simulation        Squad Validation
    │                  │
    ▼                  │
Phase 4 (US2)  ◄───────┘
Match System
    │
    ▼
Phase 6 (Polish)
```

### Within Each Phase

- Tests (T015-T022, T040-T041, T047) MUST be written and FAIL before implementation
- Runtime structs before system logic
- Utility functions before complex systems
- Individual tier implementations before orchestration (tick loop)

### Parallel Opportunities

**Phase 2** (all [P] tasks):
```
T006 (constants) ║ T007 (enums/structs) ║ T008 (RNG) ║ T009 (math) ║ T010 (grid models) ║ T011 (runtime structs) ║ T012 (events)
T013 (RNG tests) ║ T014 (math tests)
```

**Phase 3 — US1 Tests** (all [P]):
```
T015 (T1 tests) ║ T016 (T2 tests) ║ T017 (T3 tests) ║ T018 (T4 tests) ║ T019 (T5 tests) ║ T020 (monster tests) ║ T021 (shield tests) ║ T022 (regression tests)
```

**Phase 3 — US1 Implementation** (sequential dependency chain):
```
T023 (grid utils) → T024 (spawning) → T025 (movement) ║ T026-T032 (tower attacks — can parallel per tier)
T033 (process attacks) → T034 (process movement) → T035 (cleanup) → T036 (win condition) → T037 (tick loop) → T038 (contract)
```

**Phase 4 — US2**: T042 (models) can parallel with T040-T041 (tests), then T043-T046 sequential

**Phase 5 — US3**: T048 can parallel with T047 (tests), then T049-T052 sequential

---

## Parallel Example: User Story 1

```bash
# Launch all US1 tests in parallel (write first, all should fail):
T015: "Tower tier 1 freeze tests"
T016: "Tower tier 2 AoE tests"
T017: "Tower tier 3 global tests"
T018: "Tower tier 4 double-shot tests"
T019: "Tower tier 5 tank-buster tests"
T020: "Monster tier behavior tests"
T021: "Shield absorption tests"
T022: "Full simulation regression tests"

# Then implement tier attacks in parallel (different functions, same file but independent):
T027: "T1 freeze attack"
T028: "T2 AoE attack"
T029: "T3 global attack"
T030: "T4 double-shot attack"
T031: "T5 tank-buster attack"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T014)
3. Complete Phase 3: User Story 1 (T015-T039)
4. **STOP and VALIDATE**: Run `sozo test`, verify simulation matches JS reference
5. Deploy to Katana, manually test with known configs

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 (simulation) → Test independently → **MVP deployed** (can run simulations)
3. US3 (squad validation) → Test independently → Budget system works
4. US2 (match system) → Test independently → **Full game deployed** (create/join/resolve matches)
5. Polish → Gas benchmarks, edge cases, deployment hardening

### Parallel Team Strategy

With 2+ developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US1 (simulation engine) — critical path
   - Developer B: US3 (squad validation) — independent, no dependency on US1
3. US2 (match system) starts after US1 completes, integrates US3
4. Polish phase together

---

## Notes

- [P] tasks = different files or independent functions, no dependencies
- [Story] label maps task to specific user story for traceability
- All Cairo file paths are relative to `contracts/` directory
- JS reference engine = `SimulationEngine.js` (canonical), NOT `.jsx`
- T039 (JS test vector generation) is the bridge between JS and Cairo — generate it early
- Shield behavior follows .js (absorbs ALL, remaining → 0), NOT .jsx (pass-through)
- Integer math throughout: `ceil(a/b)` = `(a + b - 1) / b`, 1.5x = `(v * 3) / 2`
