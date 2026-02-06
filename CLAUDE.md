# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Beast Tower Defense is a competitive, asymmetric 1v1 tower defense game built around Loot Survivor BEASTs. Players wager and compete in two-round matches, swapping attacker/defender roles between rounds. The same beast NFT serves as either a Tower (defense) or Monster (attack) depending on role.

## Architecture

The codebase is a deterministic simulation engine with no build system, package manager, or test framework. There are two implementation variants:

- **SimulationEngine.js** — Canonical version. Uses Mulberry32 seeded PRNG, Manhattan distance for range, 4-directional pathing, ES6 class methods throughout. Exports via ES modules.
- **SimulationEngine.jsx** — React-compatible variant. Uses sin-based seeded PRNG, Chebyshev distance for range, 8-directional pathing, prototype-based methods for SimulationEngine. Includes tick_start/tick_end log events and health-pool tiebreaker. Also has `getLogByTick`/`getLogByEvent` query methods.

### Class Hierarchy

```
Beast (id, name, tier, type, level, health)
├── Tower (extends Beast) — fixed position, attackCounter, critChance, range
└── Monster (extends Beast) — mobile, path[], freezeTicks, shield, spawnTick
GameGrid — width, height, pathTiles, blockedTiles
SimulationEngine — orchestrates tick loop, manages towers/monsters/queue/log
```

### Tick Loop Order

```
1. spawnMonster()          — dequeue one monster per tick
2. processTowerAttacks()   — towers fire based on tier-specific attack speed
3. processMonsterMovement() — monsters advance along path tiles
4. cleanupDeadMonsters()   — remove dead from active list
5. checkWinCondition()     — finish when queue empty and no alive monsters
```

## Key Game Mechanics

**Type triangle:** Hunter > Magic > Brute > Hunter (1.5x advantage, 0.5x disadvantage)

**Tier abilities (as towers):**
- T1: Freeze — targets a tile, freezes 1-all monsters (level-scaled), no damage
- T2: AoE burst — 3x3 area damage centered on target tile, `level/10` base damage
- T3: Global — hits all alive monsters, `level/100` base damage
- T4: Double-shot — fires twice per tick, targets rightmost tile, `level` base damage, always ready
- T5: Tank-buster — targets highest HP monster in range 3, `level` base damage

**Tier behavior (as monsters):**
- T1: Slow (move every 4 ticks)
- T2: Fast (move every tick)
- T3: Splits into 4 swarm copies at `health/5` each
- T4: 10% chance to move per tick, 10% chance for multi-tile teleport
- T5: 50% max-health shield, moves every 3 ticks

**Crit system:** 20% base chance, doubles damage and freeze duration.

## Divergences Between .js and .jsx

| Aspect | SimulationEngine.js | SimulationEngine.jsx |
|---|---|---|
| PRNG | Mulberry32 (better distribution) | `Math.sin(s) * 10000` |
| Distance check | Manhattan (`withinManhattan`) | Chebyshev (`withinSquare`) |
| Pathing directions | 4-directional | 8-directional |
| T4 multi-move | 2 tiles | 3 tiles |
| T1 freeze calc | `Math.ceil(freezeDuration * multiplier)` | `freezeDuration * multiplier` (no ceil) |
| Tiebreaker | Draw only | Health-pool comparison |
| Log granularity | Minimal | tick_start/tick_end events, log query methods |
| Methods style | ES6 class methods | Prototype-based for SimulationEngine |
| T3 global range | `range: 0` triggers all-monster filter | Same |

## Design Document

`system-design.md` contains the game design spec. Several mechanics are TBD: beast cost formula, tier vulnerabilities for T3-T5, squad size limits, on-chain architecture, commit-reveal for tower placement, and fee distribution.

## Active Technologies
- Cairo 2.x (Starknet smart contract language, compiled via Scarb) + Dojo framework (ECS game engine), Scarb (Cairo package manager), Sozo (Dojo CLI), Katana (local sequencer), Torii (indexer) (001-cairo-simulation-engine-contract)
- Dojo World contract (on-chain model storage via `world.write_model` / `world.read_model`) (001-cairo-simulation-engine-contract)

## Recent Changes
- 001-cairo-simulation-engine-contract: Added Cairo 2.x (Starknet smart contract language, compiled via Scarb) + Dojo framework (ECS game engine), Scarb (Cairo package manager), Sozo (Dojo CLI), Katana (local sequencer), Torii (indexer)
