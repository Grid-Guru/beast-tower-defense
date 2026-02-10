# Implementation Plan: Provable On-Chain Simulation Engine

**Branch**: `001-cairo-simulation-engine-contract` | **Date**: 2026-02-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-cairo-simulation-engine-contract/spec.md`

## Summary

Port the canonical JavaScript simulation engine (`SimulationEngine.js`) to a Cairo/Dojo smart contract on Starknet. The contract provides trustless, deterministic battle resolution for competitive 1v1 tower defense matches with configurable ERC20 token wagers. A single-admin governance model controls map registration, token approval, and fee distribution.

## Technical Context

**Language/Version**: Cairo 2.9.x (via Dojo framework)
**Primary Dependencies**: Dojo (ECS game framework for Starknet), OpenZeppelin Cairo Contracts (ERC20 dispatcher for token transfers)
**Storage**: Dojo World (on-chain ECS storage via `#[dojo::model]`)
**Testing**: `sozo test` (Cairo test runner via Scarb)
**Target Platform**: Starknet (L2 ZK-rollup)
**Project Type**: Single project — `contracts/` directory at repo root
**Performance Goals**: Full battle simulation (5v5, ~100 ticks) completes within Starknet's per-transaction step limit
**Constraints**: No floating-point math; all arithmetic must be integer-only. PRNG must produce identical outputs to the JS Mulberry32 reference for the same seed.
**Scale/Scope**: MVP — single admin, up to 5 towers / 5 beasts per player, configurable wager tokens from protocol-approved list

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

No project constitution file exists yet. The following sensible defaults are applied:

- [x] Single deployment target (Starknet) — no multi-chain complexity
- [x] Single project structure (`contracts/`) — no monorepo splitting
- [x] No external runtime dependencies beyond Dojo and OpenZeppelin Cairo
- [x] No repository pattern or ORM abstraction — direct Dojo model read/write
- [x] Integer-only math — no fixed-point library

## Project Structure

### Documentation (this feature)

```text
specs/001-cairo-simulation-engine-contract/
├── plan.md              # This file
├── research.md          # Phase 0 output — 13 research decisions
├── data-model.md        # Phase 1 output — Dojo models + runtime structs
├── quickstart.md        # Phase 1 output — dev setup guide
├── contracts/           # Phase 1 output — interface definitions
│   ├── simulation.cairo
│   ├── match_actions.cairo
│   ├── squad.cairo
│   └── events.cairo
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
contracts/
├── src/
│   ├── lib.cairo
│   ├── models/
│   │   ├── beast.cairo        # BeastType enum, BeastConfig struct
│   │   ├── grid.cairo         # GameGrid, GridPathTile, GridBlockedTile
│   │   ├── match_state.cairo  # Match, PlayerSetup, PlayerTower, PlayerBeast, MatchResult
│   │   ├── admin.cairo        # AdminConfig, ApprovedToken
│   │   └── simulation.cairo   # SimulationResult (output struct)
│   ├── systems/
│   │   ├── simulation.cairo   # Core tick loop — spawn, attack, move, cleanup, win check
│   │   ├── match_actions.cairo # create_match, join_match, cancel_match + ERC20 escrow
│   │   ├── squad.cairo        # validate_towers, validate_beasts, beast_cost
│   │   └── admin.cairo        # register_map, approve_token, revoke_token, set_fee_recipient, transfer_admin
│   ├── utils/
│   │   ├── rng.cairo          # Mulberry32 PRNG (u32 wrapping arithmetic)
│   │   ├── math.cairo         # ceil_div, type_multiplier
│   │   └── constants.cairo    # Tier configs, game limits, fee percentage
│   └── events.cairo           # All Dojo event structs
├── tests/
│   ├── test_rng.cairo         # Mulberry32 output parity with JS
│   ├── test_type_chart.cairo  # All 9 type combinations
│   ├── test_tower_tiers.cairo # T1-T5 attack behaviors
│   ├── test_monster_tiers.cairo # T1-T5 movement/abilities
│   ├── test_simulation.cairo  # Full simulation regression vs JS reference
│   ├── test_match.cairo       # Match lifecycle, wager escrow, payouts
│   ├── test_squad.cairo       # Budget validation, cost calculation
│   └── test_admin.cairo       # Admin functions, access control
├── Scarb.toml
├── dojo_dev.toml
└── katana.toml
```

**Structure Decision**: Single `contracts/` project using Dojo's ECS architecture. Models define persistent state. Systems implement game logic. Utils hold pure functions. Tests mirror source structure.

## Key Design Decisions

### 1. Simulation Runs Entirely In-Memory

The full tick loop (spawn → attack → move → cleanup → win check) executes within a single function call. All runtime state (towers, monsters, queue, RNG) lives in local variables. Only the final `MatchResult` is persisted via `world.write_model()`. Events are emitted during simulation for Torii indexing at zero storage cost.

**Why**: Per-tick storage writes would be prohibitively expensive on Starknet. A 100-tick simulation with 5v5 involves ~1000 iterations of per-entity logic — easily within Starknet's compute (step) limits since there are no storage operations per tick.

### 2. Canonical JS Engine as Reference (SimulationEngine.js)

All mechanics follow `SimulationEngine.js` exclusively:
- Mulberry32 PRNG (not sin-based)
- Manhattan distance (not Chebyshev)
- 4-directional pathing (not 8-directional)
- Shield absorbs ALL damage, remaining damage → 0 (not pass-through)
- T3 spawns 4 simultaneously from 1 queue entry (not 4 queue entries)
- T4 teleport = 2 tiles (not 3)
- T1 freeze uses ceil (not raw multiplication)
- Tiebreaker = draw only (not health-pool comparison)

### 3. ERC20 Token Wagers with Configurable Approved List

Match wagers use ERC20 token transfers (not native ETH value). The match creator selects a token from the protocol-approved list. The contract uses OpenZeppelin's `IERC20Dispatcher` for `transfer_from` (escrow on create/join) and `transfer` (payout on resolution/cancel).

**Why**: Spec clarification Q1 — configurable per match from approved list. Allows flexibility for LORDS, ETH, STRK, or any future token without contract upgrades.

### 4. Single Admin with Ownership Transfer

One admin address (initially deployer) controls:
- Map registration (`register_map`)
- Token approval/revocation (`approve_token`, `revoke_token`)
- Fee recipient address (`set_fee_recipient`)
- Admin transfer (`transfer_admin`)

All admin functions assert `caller == admin`. No multi-sig or timelocked governance in MVP.

### 5. Per-Match Squad Budget

The match creator sets the squad point budget when creating the match. Both players must build squads (towers + beasts) within this same budget. Budget is stored on the `Match` model and validated during `create_match` and `join_match`.

**Why**: Spec clarification Q4 — per-match, creator sets it. Enables flexible competitive formats without protocol-wide constraints.

## Complexity Tracking

No constitution violations to document — the project uses a single codebase, single storage backend, no external dependencies beyond Dojo/OpenZeppelin, and no abstraction layers.
