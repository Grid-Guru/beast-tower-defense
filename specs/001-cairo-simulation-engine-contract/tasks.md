# Tasks: Provable On-Chain Simulation Engine

**Input**: Design documents from `/specs/001-cairo-simulation-engine-contract/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included — the spec requires deterministic regression tests against the JS reference engine (SC-001 through SC-008), and the plan mandates test-first development.

**Organization**: Tasks grouped by user story. US1 (simulation engine) is the MVP.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- All file paths relative to `contracts/` directory

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the Dojo project, directory structure, and build configuration.

- [x] T001 Initialize Dojo project: create `contracts/Scarb.toml` with `beast_td` package name, Dojo dependency, OpenZeppelin Cairo Contracts dependency, and `[[target.dojo]]`
- [x] T002 Create `contracts/dojo_dev.toml` with world name `Beast Tower Defense`, namespace `beast_td`, local RPC, and writer permissions for all four system contracts (simulation, match_actions, squad, admin)
- [x] T003 [P] Create `contracts/katana.toml` with default Katana sequencer config
- [x] T004 Create directory structure: `contracts/src/{models,systems,utils}` and `contracts/tests/`
- [x] T005 Create `contracts/src/lib.cairo` with module declarations for all submodules: `models`, `systems`, `utils`, `events`
- [x] T006 Verify `sozo build` compiles the empty project successfully

**Checkpoint**: `sozo build` should succeed with empty modules (no compilation errors).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utilities, constants, enums, and shared models that ALL user stories depend on. Must complete before any story begins.

**CRITICAL**: No user story work can begin until this phase is complete.

### Constants, Enums & Shared Types

- [x] T007 [P] Define all game constants in `contracts/src/utils/constants.cairo`: tower tier configs (attack_speed, range per tier), monster tier configs (step_ticks per tier), game limits (MAX_TICKS=1000, MAX_TOWERS=5, MAX_BEASTS=5, MAX_GRID_SIZE=32, MAX_PATH_LENGTH=64), combat params (DEFAULT_CRIT_CHANCE=20, SWARM_COUNT=4, SWARM_HEALTH_DIVISOR=5, SHIELD_HEALTH_PCT=50, T4_MOVE_CHANCE_PCT=10, T4_TELEPORT_CHANCE_PCT=10, T4_TELEPORT_TILES=2), economy (WAGER_FEE_PCT=5), admin (ADMIN_CONFIG_ID=1)
- [x] T008 [P] Define enums and input/output structs in `contracts/src/models/beast.cairo`: BeastType enum (Hunter, Magic, Brute), TowerInput struct (beast_id, name, tier, beast_type, level, health, pos_x, pos_y), BeastInput struct (beast_id, name, tier, beast_type, level, health), SimulationResult struct (winner, monsters_killed, monsters_escaped, total_ticks); derive Copy, Drop, Serde on all
- [x] T009 [P] Define MatchStatus enum in `contracts/src/models/match_state.cairo`: AwaitingOpponent, InProgress, Completed, Cancelled; derive Copy, Drop, Serde, PartialEq

### PRNG (Critical Path)

- [x] T010 [P] Implement Mulberry32 seeded PRNG in `contracts/src/utils/rng.cairo`: `rng_next(ref state: u32) -> u32` using WrappingAdd/WrappingMul, `rng_int(ref state: u32, max: u32) -> u32` via modulo, `rng_chance(ref state: u32, pct: u8) -> bool` for percentage checks, `rng_shuffle<T>(ref state: u32, ref arr: Array<T>)` for Fisher-Yates shuffle. Port the exact Mulberry32 algorithm from SimulationEngine.js lines 38-45

### Math Utilities

- [x] T011 [P] Implement math helpers in `contracts/src/utils/math.cairo`: `ceil_div(a: u32, b: u32) -> u32` for Math.ceil equivalent, `get_type_multiplier(attacker_type: u8, defender_type: u8) -> (u32, u32)` returning (numerator, denominator) for the type triangle, `apply_multiplier(value: u32, num: u32, den: u32) -> u32` applying `ceil_div(value * num, den)`, `within_manhattan(x1: u8, y1: u8, x2: u8, y2: u8, range: u8) -> bool`

### Grid Model

- [x] T012 [P] Define GameGrid Dojo models in `contracts/src/models/grid.cairo`: `GameGrid` model keyed by grid_id with width/height/start_x/start_y/end_x/end_y/path_count/blocked_count, `GridPathTile` model keyed by (grid_id, index) with x/y, `GridBlockedTile` model keyed by (grid_id, index) with x/y. Derive Copy, Drop, Serde with `#[dojo::model]`

### Runtime Structs

- [x] T013 [P] Define simulation runtime structs in `contracts/src/models/simulation.cairo`: `Tower` struct (id, tier, beast_type, level, health, pos_x, pos_y, attack_counter, crit_chance, range), `Monster` struct (id, tier, beast_type, level, health, max_health, pos_x, pos_y, last_x, last_y, has_last_tile, alive, freeze_ticks, shield, spawn_tick), `SimulationState` struct (rng_state, current_tick, monsters_escaped, monsters_killed, finished, winner). These are NOT Dojo models — plain Cairo structs

### Events

- [x] T014 [P] Define all Dojo events in `contracts/src/events.cairo`: match lifecycle (MatchCreated with wager_token/wager_amount/budget, MatchJoined, MatchResolved, MatchCancelled), admin (TokenApproved, TokenRevoked, MapRegistered, AdminTransferred, FeeRecipientUpdated), simulation (SpawnEvent, DamageEvent, FreezeEvent, KillEvent, EscapeEvent, GameEndEvent, MoveEvent). Each with `#[dojo::event]` and appropriate `#[key]` fields per contracts/events.cairo design artifact

### Admin Models

- [x] T015 [P] Define AdminConfig and ApprovedToken Dojo models in `contracts/src/models/admin.cairo`: AdminConfig singleton keyed by config_id (always 1) with admin and fee_recipient ContractAddresses, ApprovedToken keyed by token ContractAddress with approved bool. Derive Copy, Drop, Serde with `#[dojo::model]`

### Foundational Tests

- [x] T016 [P] Write PRNG determinism tests in `contracts/tests/test_rng.cairo`: test that `rng_next` with seed 12345 produces the exact same sequence as JS Mulberry32 with seed 12345 (capture first 10 values from JS engine as expected). Test `rng_int` distribution and `rng_chance` thresholds
- [x] T017 [P] Write type chart and math tests in `contracts/tests/test_type_chart.cairo`: test all 9 type combinations (Hunter/Magic/Brute x Hunter/Magic/Brute) return correct (num, den) pairs. Test `apply_multiplier` with ceil behavior matching `Math.ceil(damage * multiplier)` from JS. Test `within_manhattan` with known coordinate pairs. Test `ceil_div` edge cases (0/1, 1/1, 3/2, 10/3)

**Checkpoint**: `sozo build` compiles successfully. `sozo test` passes all foundational tests. RNG output matches JS reference values.

---

## Phase 3: User Story 1 — Resolve a Battle Trustlessly (Priority: P1) MVP

**Goal**: Execute the full tick-based simulation loop on-chain, producing identical results to SimulationEngine.js for any given (config, seed) pair.

**Independent Test**: Call `run_simulation` with a known config + seed, assert result matches JS engine output for winner, monstersKilled, monstersEscaped, totalTicks.

### Tests for User Story 1

> **Write these tests FIRST. They MUST FAIL before implementation.**

- [x] T018 [P] [US1] Write tower tier 1 (freeze) tests in `contracts/tests/test_tower_tiers.cairo`: test freeze targets correct count based on level thresholds (<30=1, 30-59=2, 60-99=3, 100+=all), test T5 monsters are skipped, test crit doubles freeze duration, test type multiplier applied with ceil, test freeze accumulates on monster
- [x] T019 [P] [US1] Write tower tier 2 (AoE) tests in `contracts/tests/test_tower_tiers.cairo`: test 3x3 area damage centered on target tile, test `ceil(level/10)` base damage, test type multiplier applied per monster, test crit doubles damage
- [x] T020 [P] [US1] Write tower tier 3 (global) tests in `contracts/tests/test_tower_tiers.cairo`: test hits all alive monsters regardless of position, test `ceil(level/100)` base damage, test type multiplier per monster
- [x] T021 [P] [US1] Write tower tier 4 (double-shot) tests in `contracts/tests/test_tower_tiers.cairo`: test fires twice per tick, test targets rightmost tile, test `level` base damage (not divided), test always ready (no attack counter)
- [x] T022 [P] [US1] Write tower tier 5 (tank-buster) tests in `contracts/tests/test_tower_tiers.cairo`: test targets highest HP monster (health + shield), test range 3, test `level` base damage
- [x] T023 [P] [US1] Write monster tier behavior tests in `contracts/tests/test_monster_tiers.cairo`: T1 moves every 4 ticks, T2 moves every tick, T3 spawns as 4 copies with ceil(health/5) each, T4 has 10% move chance and 10% teleport (2 tiles), T5 gets ceil(50% health) shield and moves every 3 ticks
- [x] T024 [P] [US1] Write shield absorption tests in `contracts/tests/test_monster_tiers.cairo`: test shield absorbs damage and zeroes remaining (per .js canonical — NOT pass-through), test shield depletes correctly over multiple hits
- [x] T025 [P] [US1] Write full simulation regression tests in `contracts/tests/test_simulation.cairo`: run SimulationEngine.js with 3+ different configs/seeds, capture exact outputs (winner, killed, escaped, ticks), assert Cairo produces identical results

### Implementation for User Story 1

- [x] T026 [US1] Implement grid utility functions in `contracts/src/systems/simulation.cairo`: `get_adjacent_path_tiles(x, y, ref path_tiles) -> Array<(u8, u8)>` returning 4-directional neighbors that are path tiles, `is_end_tile(x, y, end_x, end_y) -> bool`, `get_surrounding_tiles(x, y, range, width, height) -> Array<(u8, u8)>` for AoE, `sort_tile_keys(ref tiles) -> Array<(u8, u8)>` for deterministic tile ordering (sort by x ascending, then y ascending)
- [x] T027 [US1] Implement monster spawning in `contracts/src/systems/simulation.cairo`: `spawn_monster(ref state, ref monsters, ref queue, start_x, start_y)` — dequeue one entry, create Monster struct. For T3 (isSwarm): spawn 4 copies with `ceil_div(health, 5)`, mark split=true. For T5: set shield = `ceil_div(health * 50, 100)`. Emit SpawnEvent per monster
- [x] T028 [US1] Implement monster movement in `contracts/src/systems/simulation.cairo`: `move_monster(ref monster, ref state, ref path_tiles, end_x, end_y)` — handle freeze tick decrement, `can_move` check per tier (T4: rng_chance(10%)), get 4-dir neighbors excluding last_tile (backtrack prevention), random selection via rng_int. T4 teleport: separate rng_chance(10%) for 2-tile move. Update position and last_tile. Check end tile → escape. Emit MoveEvent per step
- [x] T029 [US1] Implement `monster_escaped` helper in `contracts/src/systems/simulation.cairo`: mark alive=false, increment monsters_escaped, emit EscapeEvent
- [x] T030 [US1] Implement tower attack dispatch in `contracts/src/systems/simulation.cairo`: `tower_attack(ref tower, ref monsters, ref state)` — roll crit via rng_chance(20), dispatch to tier-specific function. Implement `get_monsters_in_range` using Manhattan distance (range=0 → all alive), `get_tiles_with_monsters_in_range` returning sorted tile→monsters map, `get_monsters_at_tile`
- [x] T031 [US1] Implement T1 freeze attack in `contracts/src/systems/simulation.cairo`: pick random tile from sorted tile keys, determine freeze count by level thresholds (1 if <30, 2 if 30-59, 3 if 60-99, all if >=100), shuffle monsters on tile, apply freeze = ceil(1 * critMultiplier * typeMultiplier), skip T5 monsters. Emit FreezeEvent
- [x] T032 [P] [US1] Implement T2 AoE attack in `contracts/src/systems/simulation.cairo`: pick random target tile from sorted keys, damage = ceil_div(level * critMultiplier, 10), get 3x3 surrounding tiles + center, apply damage with type multiplier per monster. Emit DamageEvent per hit, call apply_damage
- [x] T033 [P] [US1] Implement T3 global attack in `contracts/src/systems/simulation.cairo`: damage = ceil_div(level * critMultiplier, 100), iterate all alive monsters, apply damage with type multiplier. Emit DamageEvent per hit
- [x] T034 [P] [US1] Implement T4 double-shot attack in `contracts/src/systems/simulation.cairo`: loop 2 shots, find rightmost tile from sorted keys, pick random monster on that tile, damage = level * critMultiplier, apply type multiplier with ceil. Emit DamageEvent
- [x] T035 [P] [US1] Implement T5 tank-buster attack in `contracts/src/systems/simulation.cairo`: find monster with highest (health + shield) in range 3 via Manhattan distance, damage = level * critMultiplier, apply type multiplier with ceil. Emit DamageEvent
- [x] T036 [US1] Implement `apply_damage` in `contracts/src/systems/simulation.cairo`: if T5 with shield > 0: shield absorbs ALL damage (set remaining damage = 0 regardless of shield vs damage comparison, per canonical .js), reduce shield by min(damage_before, shield); subtract final damage from health. If health <= 0: mark dead, increment monsters_killed, emit KillEvent
- [x] T037 [US1] Implement `process_tower_attacks` in `contracts/src/systems/simulation.cairo`: iterate towers, T4 always fires, others increment attack_counter and fire when counter >= attack_speed then reset counter. Call tower_attack for each firing tower
- [x] T038 [US1] Implement `process_monster_movement` in `contracts/src/systems/simulation.cairo`: iterate all alive monsters, call move_monster for each
- [x] T039 [US1] Implement `cleanup_dead_monsters` in `contracts/src/systems/simulation.cairo`: filter monsters array to only alive entries
- [x] T040 [US1] Implement `check_win_condition` and `determine_winner` in `contracts/src/systems/simulation.cairo`: queue empty AND all monsters dead/escaped → finished=true. Winner: killed > escaped → defender, escaped > killed → attacker, else → draw. Emit GameEndEvent
- [x] T041 [US1] Implement tick loop and `run_simulation` entry point in `contracts/src/systems/simulation.cairo`: `tick()` calls spawn→attacks→movement→cleanup→win_check in exact order. `run_simulation()` loops tick until finished or current_tick >= max_ticks, force-determines winner on timeout. Build Tower/Monster arrays from TowerInput/BeastInput, load grid path tiles from Dojo World, return SimulationResult
- [x] T042 [US1] Create `#[dojo::contract] mod simulation` in `contracts/src/systems/simulation.cairo`: implement `ISimulation` trait with `run_simulation` function that reads GameGrid + path/blocked tiles from World, constructs runtime state, runs simulation loop, returns SimulationResult

### Generate JS Reference Test Data

- [x] T043 [US1] Create test data generator script at `scripts/generate_test_vectors.js`: run SimulationEngine.js with 3+ test configs (simple 1v1, multi-tower multi-beast, all-escape, all-kill, T3 swarm, T5 shield), capture exact RNG sequence (first 10 raw u32 values for seed 12345 before division), capture exact simulation outputs. Output as Cairo-compatible constants for test files

**Checkpoint**: `sozo test` passes all US1 tests. Simulation output matches JS reference engine for all test vectors. MVP is functional.

---

## Phase 4: User Story 2 — Compete in a 1v1 Wagered Match (Priority: P2)

**Goal**: Enable two players to create, join, and resolve a 1v1 match with ERC20 token wager escrow, configurable per-match budget, and 2-round execution. Admin manages maps, approved tokens, and fee recipient.

**Independent Test**: Player 1 creates a match with a wager (choosing token and budget), Player 2 joins with matching wager, both rounds execute, winner receives 95% of pot, protocol receives 5%.

**Depends on**: US1 (simulation engine must work), Phase 2 (admin models for token approval)

### Tests for User Story 2

- [x] T044 [P] [US2] Write match lifecycle tests in `contracts/tests/test_match.cairo`: test create_match stores Match model with AwaitingOpponent status, wager_token, wager_amount, budget; test wager is escrowed via ERC20 transfer_from; test join_match transitions to Completed; test both rounds execute with correct role swapping (R1: P1 towers vs P2 beasts, R2: P2 towers vs P1 beasts); test winner determination from net scores; test payout distribution (95% winner / 5% fee per SC-008 — fee = total_pot - winner_payout to avoid rounding dust); test draw refunds both players in full with no fee charged; test tiebreak by squad cost (lower cost wins per spec)
- [x] T045 [P] [US2] Write match error case tests in `contracts/tests/test_match.cairo`: test CANNOT_JOIN_OWN_MATCH (FR-013), test MATCH_NOT_FOUND, test MATCH_NOT_AWAITING (join completed match), test cancel_match only by player1, test cancel refunds wager, test ZERO_WAGER rejected, test TOKEN_NOT_APPROVED rejected, test ZERO_BUDGET rejected
- [x] T046 [P] [US2] Write admin tests in `contracts/tests/test_admin.cairo`: test register_map stores grid and path/blocked tiles correctly; test approve_token/revoke_token toggle ApprovedToken.approved; test set_fee_recipient updates AdminConfig; test transfer_admin changes admin address; test ALL admin functions reject non-admin callers (FR-022); test register duplicate grid_id rejected; test invalid grid dimensions rejected; test zero address rejected for transfer_admin/set_fee_recipient/approve_token

### ERC20 Mock

- [x] T047 [US2] Create ERC20 mock contract for test environment in `contracts/tests/helpers/mock_erc20.cairo`: minimal ERC20 with mint, approve, transfer_from, transfer, balance_of for use in match and admin tests. Must implement IERC20 interface from OpenZeppelin

### Implementation for User Story 2

- [x] T048 [P] [US2] Define Match Dojo model in `contracts/src/models/match_state.cairo`: match_id (key), player1, player2, grid_id, wager_token (ContractAddress), wager_amount (u256), budget (u32), status (MatchStatus), seed (u64), winner (ContractAddress). Add MatchResultOutput struct for return values, MatchView struct for get_match
- [x] T049 [P] [US2] Define PlayerSetup, PlayerTower, PlayerBeast Dojo models in `contracts/src/models/match_state.cairo`: PlayerSetup keyed by (match_id, player) with tower_count, beast_count, total_cost; PlayerTower keyed by (match_id, player, index) with beast stats + position; PlayerBeast keyed by (match_id, player, index) with beast stats
- [x] T050 [P] [US2] Define MatchResult Dojo model in `contracts/src/models/match_state.cairo`: keyed by match_id with r1_killed, r1_escaped, r1_ticks, r1_winner, r2_killed, r2_escaped, r2_ticks, r2_winner, final_winner, p1_net_score (i32), p2_net_score (i32)
- [x] T051 [US2] Implement admin system contract in `contracts/src/systems/admin.cairo` as `#[dojo::contract]`: `register_map` (validate grid dimensions 1-32, path not empty, start/end on path, no path/blocked overlap, write GameGrid + GridPathTile + GridBlockedTile, emit MapRegistered); `approve_token` (validate non-zero address, set ApprovedToken.approved=true, emit TokenApproved); `revoke_token` (set approved=false, emit TokenRevoked — does not affect in-progress matches); `set_fee_recipient` (validate non-zero, update AdminConfig, emit FeeRecipientUpdated); `transfer_admin` (validate non-zero, update AdminConfig, emit AdminTransferred); `is_token_approved` (view); `get_admin_config` (view). ALL mutating functions: read AdminConfig, assert caller == admin
- [x] T052 [US2] Implement `create_match` in `contracts/src/systems/match_actions.cairo` as `#[dojo::contract]`: validate grid_id registered (read GameGrid), wager_amount > 0, budget > 0, wager_token approved (read ApprovedToken), towers/beasts not empty and len <= MAX; validate tower placement (read path/blocked tiles — not on path, not blocked, in bounds, no duplicate positions); validate squad cost within budget (call beast_cost for each, sum <= budget); generate match_id (increment counter or hash); escrow wager via IERC20Dispatcher: `token.transfer_from(caller, contract_address, wager_amount)`; write Match (status=AwaitingOpponent), PlayerSetup, PlayerTower, PlayerBeast; emit MatchCreated with wager_token, wager_amount, budget; return match_id
- [x] T053 [US2] Implement `join_match` in `contracts/src/systems/match_actions.cairo`: validate match exists + AwaitingOpponent, caller != player1 (FR-013), P2 towers/beasts valid, squad cost within match.budget; escrow P2 wager via transfer_from (same token, same amount); write P2 setup; set status=InProgress; run Round 1: simulation(seed, grid, P1_towers, P2_beasts, MAX_TICKS); run Round 2: simulation(seed+1, grid, P2_towers, P1_beasts, MAX_TICKS); compute net scores (p1_net = r2_escaped - r1_escaped, p2_net = r1_escaped - r2_escaped); determine winner (higher net wins; tied → compare total squad cost, lower wins; still tied → draw); write MatchResult; distribute payout: winner_payout = total_pot * 95 / 100, fee = total_pot - winner_payout, token.transfer(winner, winner_payout), token.transfer(fee_recipient, fee); on draw: token.transfer(player1, wager_amount), token.transfer(player2, wager_amount), no fee; set status=Completed; emit MatchJoined + MatchResolved; return MatchResultOutput
- [x] T054 [US2] Implement `cancel_match` in `contracts/src/systems/match_actions.cairo`: validate caller == player1, status == AwaitingOpponent; refund via token.transfer(player1, wager_amount); set status=Cancelled; emit MatchCancelled
- [x] T055 [US2] Implement `get_match` view function in `contracts/src/systems/match_actions.cairo`: read Match model, return MatchView struct with all fields including wager_token, wager_amount, budget

**Checkpoint**: `sozo test` passes all US2 tests. Full match flow works end-to-end: create → join → resolve → payout. Admin controls access correctly. ERC20 escrow and distribution verified.

---

## Phase 5: User Story 3 — Build a Squad Within Budget (Priority: P3)

**Goal**: Validate squad compositions against a per-match point budget to ensure competitive fairness. Beast cost = level + health.

**Independent Test**: Call `validate_towers` and `validate_beasts` with various compositions against a fixed budget, verify over-budget squads are rejected while valid squads are accepted.

**Depends on**: Phase 2 foundational models only. Can be developed in parallel with US1.

### Tests for User Story 3

- [x] T056 [P] [US3] Write squad validation tests in `contracts/tests/test_squad.cairo`: test `beast_cost(50, 100)` returns 150 (SC acceptance scenario 3); test valid squad (total cost within budget) passes; test over-budget squad reverts SQUAD_OVER_BUDGET; test empty squad reverts EMPTY_SQUAD (FR-018); test invalid tier (0, 6) reverts; test invalid beast_type (0, 4) reverts; test zero health reverts; test zero level reverts; test tower count > MAX_TOWERS reverts; test beast count > MAX_BEASTS reverts; test tower on path tile reverts; test tower on blocked tile reverts; test tower out of bounds reverts; test duplicate tower position reverts

### Implementation for User Story 3

- [x] T057 [P] [US3] Implement `beast_cost` in `contracts/src/systems/squad.cairo`: `beast_cost(level: u16, health: u32) -> u32` returning `level.into() + health` (per spec assumptions: cost = level + health)
- [x] T058 [US3] Implement `validate_towers` in `contracts/src/systems/squad.cairo`: check towers not empty, len <= MAX_TOWERS; each tower: tier in 1-5, beast_type in 1-3, level > 0, health > 0, pos_x < grid.width, pos_y < grid.height, not path tile, not blocked tile; no duplicate positions; sum(beast_cost) <= budget. Read grid data from Dojo World. Return (valid: bool, total_cost: u32)
- [x] T059 [US3] Implement `validate_beasts` in `contracts/src/systems/squad.cairo`: check beasts not empty, len <= MAX_BEASTS; each beast: tier in 1-5, beast_type in 1-3, level > 0, health > 0; sum(beast_cost) <= budget. Return (valid: bool, total_cost: u32)
- [x] T060 [US3] Create `#[dojo::contract] mod squad` in `contracts/src/systems/squad.cairo`: implement `ISquad` trait exposing `validate_towers`, `validate_beasts`, `beast_cost` as contract functions
- [x] T061 [US3] Integrate budget validation into match_actions in `contracts/src/systems/match_actions.cairo`: verify `create_match` and `join_match` call `validate_towers` and `validate_beasts` with match.budget, revert with SQUAD_OVER_BUDGET if validation fails. Verify both players are validated against the same budget (the one set by the creator per FR-017)

**Checkpoint**: `sozo test` passes all US3 tests. Budget validation prevents unfair squads. Integration with match system verified.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, optimization, and deployment readiness.

- [x] T062 Register at least one reference GameGrid in a deployment init script or test helper: define a playable map (e.g., 10x10 grid with a winding path), call admin.register_map with path/blocked tiles
- [x] T063 [P] Gas/step benchmarking: run a worst-case simulation (5 towers including T3 global, 5 beasts including T3 swarm = up to 20 monsters, ~1000 ticks) on Katana, capture step count, verify within Starknet transaction limits (SC-005)
- [x] T064 [P] Edge case hardening: test and handle max_ticks timeout (force-end + determine winner), empty monster queue at start, monsters with very high health, grid with single-tile path (start == end → immediate escape), T3 swarm with health < 5 (ceil ensures at least 1 HP each)
- [x] T065 [P] Review all error messages across all systems for clarity and specificity — every revert must have a unique, descriptive error string (SC-007)
- [x] T066 Run full `sozo build && sozo test` to validate all tests pass, no compilation warnings
- [ ] T067 Validate quickstart.md instructions end-to-end: follow from scratch on clean environment — install Dojo, build, test, deploy to Katana, register map via admin, approve a token, create a match, join a match, verify correct outcome and payout

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (T006 build passes) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — BLOCKS US2 (match system calls simulation)
- **US2 (Phase 4)**: Depends on Phase 2 + US1 (calls run_simulation internally)
- **US3 (Phase 5)**: Depends on Phase 2 only — CAN run in parallel with US1
- **Polish (Phase 6)**: Depends on all stories being complete

### User Story Dependencies

```
Phase 1 (Setup)
    |
    v
Phase 2 (Foundational)
    |
    +-----------------+
    v                 v
Phase 3 (US1)    Phase 5 (US3)
Simulation       Squad Validation
    |                 |
    v                 |
Phase 4 (US2) <-------+
Match System
    |
    v
Phase 6 (Polish)
```

### Within Each Phase

- Tests (T018-T025, T044-T046, T056) MUST be written and FAIL before implementation
- Runtime structs before system logic
- Utility functions before complex systems
- Individual tier implementations before orchestration (tick loop)
- Models before system contracts

### Parallel Opportunities

**Phase 2** (all [P] tasks):
```
T007 (constants) | T008 (enums) | T009 (match enums) | T010 (RNG) | T011 (math) | T012 (grid) | T013 (runtime) | T014 (events) | T015 (admin models)
T016 (RNG tests) | T017 (math tests)
```

**Phase 3 — US1 Tests** (all [P]):
```
T018 (T1 tests) | T019 (T2 tests) | T020 (T3 tests) | T021 (T4 tests) | T022 (T5 tests) | T023 (monster tests) | T024 (shield tests) | T025 (regression tests)
```

**Phase 3 — US1 Tier Attacks** (after T030 dispatch):
```
T032 (T2 AoE) | T033 (T3 global) | T034 (T4 double-shot) | T035 (T5 tank-buster)
```

**Phase 4 — US2 Models** (all [P]):
```
T048 (Match) | T049 (PlayerSetup/Tower/Beast) | T050 (MatchResult)
```

**Phase 4 — US2 Tests** (all [P]):
```
T044 (lifecycle tests) | T045 (error tests) | T046 (admin tests)
```

**Phase 5 — US3**: T057 (beast_cost) parallel with T056 (tests)

---

## Parallel Example: User Story 1

```
# Launch all US1 tests in parallel (write first, all should fail):
T018: "Tower tier 1 freeze tests"
T019: "Tower tier 2 AoE tests"
T020: "Tower tier 3 global tests"
T021: "Tower tier 4 double-shot tests"
T022: "Tower tier 5 tank-buster tests"
T023: "Monster tier behavior tests"
T024: "Shield absorption tests"
T025: "Full simulation regression tests"

# Implement tier attacks in parallel (independent functions):
T032: "T2 AoE attack"
T033: "T3 global attack"
T034: "T4 double-shot attack"
T035: "T5 tank-buster attack"
```

## Parallel Example: User Story 2

```
# Launch US2 models in parallel:
T048: "Match model"
T049: "PlayerSetup/Tower/Beast models"
T050: "MatchResult model"

# Launch US2 tests in parallel:
T044: "Match lifecycle tests"
T045: "Match error case tests"
T046: "Admin tests"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T006)
2. Complete Phase 2: Foundational (T007-T017)
3. Complete Phase 3: User Story 1 (T018-T043)
4. **STOP and VALIDATE**: Run `sozo test`, verify simulation matches JS reference
5. Deploy to Katana, manually test with known configs

### Incremental Delivery

1. Setup + Foundational → Foundation ready, PRNG verified
2. US1 (simulation) → Test independently → **MVP deployed** (can run trustless simulations)
3. US3 (squad validation) → Test independently → Budget enforcement works
4. US2 (match system + admin) → Test independently → **Full game deployed** (create/join/resolve wagered matches)
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
- T043 (JS test vector generation) is the bridge between JS and Cairo — generate early
- Shield behavior follows .js (absorbs ALL, remaining → 0), NOT .jsx (pass-through)
- Integer math throughout: `ceil(a/b)` = `(a + b - 1) / b`, 1.5x = `(v * 3) / 2`
- ERC20 wager tokens: players must call `token.approve(contract, amount)` before create/join
- Admin bootstrap: after deploy, call approve_token + register_map before matches can be created
- Per-match budget: creator sets it in create_match, both players validated against same value
- Total tasks: 67
