# Implementation Plan: Cairo Simulation Engine Contract

**Branch**: `001-cairo-simulation-engine-contract` | **Date**: 2026-02-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-cairo-simulation-engine-contract/spec.md`

## Summary

Port the canonical Beast Tower Defense simulation engine (SimulationEngine.js) to Cairo using the Dojo framework, producing a provable on-chain game contract. The implementation covers: deterministic tick-based simulation with seeded PRNG, 5 tower tier abilities, 5 monster tier behaviors, type advantage system, match lifecycle (create/join/resolve), wager escrow and payout, and squad budget validation. Dojo's ECS architecture maps naturally to the existing Beast/Tower/Monster/Grid class hierarchy.

## Technical Context

**Language/Version**: Cairo 2.x (Starknet smart contract language, compiled via Scarb)
**Primary Dependencies**: Dojo framework (ECS game engine), Scarb (Cairo package manager), Sozo (Dojo CLI), Katana (local sequencer), Torii (indexer)
**Storage**: Dojo World contract (on-chain model storage via `world.write_model` / `world.read_model`)
**Testing**: `sozo test` (Cairo test runner) + `snforge` for integration tests; deterministic seed-based regression tests against JS reference output
**Target Platform**: Starknet L2 (via Dojo World deployment)
**Project Type**: Single project (Dojo contracts package)
**Performance Goals**: Complete a typical simulation (5v5, ~100 ticks) within Starknet transaction gas limits; minimize storage writes by computing simulation in a single transaction
**Constraints**: No floating point in Cairo — all multipliers must use fixed-point or integer math (e.g., 1.5x = multiply by 3, divide by 2). Simulation must be fully deterministic given (config, seed). Max ticks capped to bound gas.
**Scale/Scope**: Single Dojo World contract with ~5 models, ~3 system contracts, targeting Starknet mainnet deployment after testnet validation.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

No project constitution has been ratified yet (template only). Proceeding with sensible defaults:
- **Determinism**: All game logic must produce identical results for identical inputs — this is the foundational invariant.
- **Canonical Reference**: SimulationEngine.js is the source of truth. All Cairo behavior must match it, not the .jsx variant.
- **Test-First**: Every tier ability and monster behavior gets a test case before implementation, using known seed + config pairs from the JS engine.
- **Simplicity**: Minimize on-chain storage. Simulation runs in a single transaction, only final results are persisted.

## Project Structure

### Documentation (this feature)

```text
specs/001-cairo-simulation-engine-contract/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (interface definitions)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
contracts/
├── src/
│   ├── lib.cairo                 # Main entry point, module declarations
│   ├── models/
│   │   ├── beast.cairo           # Beast, Tower, Monster models
│   │   ├── grid.cairo            # GameGrid model, path/blocked tile storage
│   │   ├── match_state.cairo     # Match model (players, wager, status, results)
│   │   └── simulation.cairo      # SimulationState (transient, not persisted)
│   ├── systems/
│   │   ├── simulation.cairo      # Core simulation engine (tick loop, tower attacks, monster movement)
│   │   ├── match_actions.cairo   # Match lifecycle (create, join, resolve)
│   │   └── squad.cairo           # Squad validation and budget checking
│   ├── utils/
│   │   ├── rng.cairo             # Mulberry32 seeded PRNG implementation
│   │   ├── math.cairo            # Fixed-point math helpers, type multiplier lookup
│   │   └── constants.cairo       # TOWER_TIERS, MONSTER_TIERS, TYPE_CHART as constants
│   └── events.cairo              # Custom Dojo events (spawn, damage, freeze, kill, escape, game_end)
├── tests/
│   ├── test_rng.cairo            # PRNG determinism tests
│   ├── test_type_chart.cairo     # Type advantage multiplier tests
│   ├── test_tower_tiers.cairo    # Per-tier tower attack behavior tests
│   ├── test_monster_tiers.cairo  # Per-tier monster behavior tests
│   ├── test_simulation.cairo     # Full simulation regression tests (vs JS reference)
│   ├── test_match.cairo          # Match lifecycle integration tests
│   └── test_squad.cairo          # Squad budget validation tests
├── Scarb.toml                    # Cairo/Dojo package config
├── dojo_dev.toml                 # Dojo dev environment config
└── katana.toml                   # Local sequencer config
```

**Structure Decision**: Single Dojo contracts package. Models in `models/`, systems in `systems/`, utilities in `utils/`. Tests mirror the source structure. No separate frontend package in this feature scope — client integration is a future feature.

## Complexity Tracking

No constitution violations to justify — the structure is straightforward for a Dojo project.

## Key Design Decisions

### 1. Simulation Execution Strategy
The simulation runs entirely within a single transaction call. The full tick loop executes in-memory (Cairo function scope), and only the final result (winner, scores, tick count) is written to storage. This avoids per-tick storage writes which would be prohibitively expensive.

### 2. No Floating Point
Cairo has no floating-point types. All multipliers are handled via integer arithmetic:
- Type advantage 1.5x = `(damage * 3) / 2`
- Type disadvantage 0.5x = `(damage * 1) / 2`
- Neutral 1.0x = `damage * 1`
- Crit 2x = `damage * 2`
- `Math.ceil` equivalent = `(a + b - 1) / b` for integer ceiling division

### 3. PRNG: Mulberry32 in Cairo
The Mulberry32 algorithm uses 32-bit integer arithmetic that maps cleanly to Cairo's `u32` type. The wrapping arithmetic (`|= 0`, `Math.imul`) translates to Cairo's wrapping operations.

### 4. ECS Mapping
| JS Class | Dojo Model | Notes |
|---|---|---|
| Beast | `#[dojo::model] Beast` | Base data, keyed by `(match_id, beast_id)` |
| Tower | Inline struct in simulation | Not persisted per-tick, used during simulation |
| Monster | Inline struct in simulation | Not persisted per-tick, used during simulation |
| GameGrid | `#[dojo::model] GameGrid` | Keyed by `grid_id`, pre-registered |
| SimulationEngine | System contract | `#[dojo::contract] mod simulation` |
| Match state | `#[dojo::model] Match` | Keyed by `match_id` |

### 5. Canonical .js as Reference
All behavior follows SimulationEngine.js, not .jsx. Key implications:
- Manhattan distance (not Chebyshev)
- 4-directional pathing (not 8)
- T4 multi-move = 2 tiles (not 3)
- T1 freeze uses ceiling (Math.ceil)
- Shield absorbs all damage (no pass-through)
- T3 spawns 4 at once from 1 queue entry
- Tiebreaker = draw (no health-pool comparison)
