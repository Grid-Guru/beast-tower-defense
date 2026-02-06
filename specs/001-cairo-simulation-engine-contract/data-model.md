# Data Model: Cairo Simulation Engine Contract

**Branch**: `001-cairo-simulation-engine-contract`
**Date**: 2026-02-06

## Entity Relationship Overview

```
GameGrid (grid_id)
    │
    ├── pathTiles: Array<(u8, u8)>
    ├── blockedTiles: Array<(u8, u8)>
    ├── startTile: (u8, u8)
    └── endTile: (u8, u8)

Match (match_id)
    │
    ├── player1: ContractAddress
    ├── player2: ContractAddress
    ├── grid_id: u32
    ├── wager: u256
    ├── status: MatchStatus
    │
    ├── PlayerSetup (match_id, player_address)
    │   ├── towers: Array<TowerConfig>
    │   └── beasts: Array<BeastConfig>
    │
    └── MatchResult (match_id)
        ├── round1: RoundResult
        ├── round2: RoundResult
        └── winner: ContractAddress

BeastConfig (value object, not persisted independently)
    ├── beast_id: u32
    ├── name: felt252
    ├── tier: u8
    ├── beast_type: BeastType (enum)
    ├── level: u16
    └── health: u32

TowerConfig (value object)
    ├── beast: BeastConfig
    └── position: (u8, u8)
```

## Dojo Models (Persisted On-Chain)

### GameGrid

Pre-registered map definitions. Immutable after registration.

```cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameGrid {
    #[key]
    pub grid_id: u32,
    pub width: u8,
    pub height: u8,
    pub start_x: u8,
    pub start_y: u8,
    pub end_x: u8,
    pub end_y: u8,
    pub path_count: u8,
    pub blocked_count: u8,
}

// Path tiles stored separately due to array storage limitations
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GridPathTile {
    #[key]
    pub grid_id: u32,
    #[key]
    pub index: u8,
    pub x: u8,
    pub y: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GridBlockedTile {
    #[key]
    pub grid_id: u32,
    #[key]
    pub index: u8,
    pub x: u8,
    pub y: u8,
}
```

**Validation rules**:
- `width` and `height` must be > 0 and <= 32 (reasonable grid bounds)
- `start` and `end` tiles must be within grid bounds
- `start` and `end` must be path tiles
- No path tile can also be a blocked tile
- Path must form a connected graph from start to end

---

### Match

Core game session entity. Tracks lifecycle from creation to resolution.

```cairo
#[derive(Copy, Drop, Serde, PartialEq)]
pub enum MatchStatus {
    AwaitingOpponent,  // Created, waiting for P2
    InProgress,        // Both players joined, simulating
    Completed,         // Both rounds done, winner determined
    Cancelled,         // Creator cancelled before opponent joined
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Match {
    #[key]
    pub match_id: u32,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub grid_id: u32,
    pub wager: u256,
    pub status: MatchStatus,
    pub seed: u64,
    pub winner: ContractAddress,
}
```

**State transitions**:
```
AwaitingOpponent → InProgress (on join_match)
AwaitingOpponent → Cancelled (on cancel_match, only by player1)
InProgress → Completed (on simulation completion)
```

**Validation rules**:
- `player2 != player1`
- `wager > 0`
- `grid_id` must reference a registered GameGrid
- Only `player1` can cancel; only while `AwaitingOpponent`

---

### PlayerSetup

Each player's tower placement and attacker squad for a match.

```cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerSetup {
    #[key]
    pub match_id: u32,
    #[key]
    pub player: ContractAddress,
    pub tower_count: u8,
    pub beast_count: u8,
    pub total_cost: u32,
}

// Individual tower placements
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerTower {
    #[key]
    pub match_id: u32,
    #[key]
    pub player: ContractAddress,
    #[key]
    pub index: u8,
    pub beast_id: u32,
    pub name: felt252,
    pub tier: u8,
    pub beast_type: u8,  // 1=hunter, 2=magic, 3=brute
    pub level: u16,
    pub health: u32,
    pub pos_x: u8,
    pub pos_y: u8,
}

// Individual attacker beasts
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerBeast {
    #[key]
    pub match_id: u32,
    #[key]
    pub player: ContractAddress,
    #[key]
    pub index: u8,
    pub beast_id: u32,
    pub name: felt252,
    pub tier: u8,
    pub beast_type: u8,
    pub level: u16,
    pub health: u32,
}
```

**Validation rules**:
- `tower_count` <= MAX_TOWERS (e.g., 5)
- `beast_count` <= MAX_BEASTS (e.g., 5)
- `total_cost` <= SQUAD_BUDGET
- Tower positions must be within grid bounds, not on path tiles, not on blocked tiles
- No two towers on the same tile
- `tier` must be 1-5
- `beast_type` must be 1-3 (hunter/magic/brute)

---

### MatchResult

Final outcome stored after both rounds complete.

```cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MatchResult {
    #[key]
    pub match_id: u32,
    pub r1_killed: u16,
    pub r1_escaped: u16,
    pub r1_ticks: u16,
    pub r1_winner: u8,       // 0=draw, 1=defender, 2=attacker
    pub r2_killed: u16,
    pub r2_escaped: u16,
    pub r2_ticks: u16,
    pub r2_winner: u8,
    pub final_winner: ContractAddress,
    pub p1_net_score: i32,    // (p1_attack_escaped - p1_defend_escaped)
    pub p2_net_score: i32,
}
```

---

## In-Memory Structs (Simulation Runtime Only)

These structs exist only during simulation execution. They are NOT Dojo models and are NOT persisted.

### Tower (runtime)

```cairo
#[derive(Copy, Drop)]
struct Tower {
    id: u8,
    tier: u8,
    beast_type: u8,
    level: u16,
    health: u32,
    pos_x: u8,
    pos_y: u8,
    attack_counter: u8,
    crit_chance: u8,   // percentage (0-100), default 20
    range: u8,
}
```

### Monster (runtime)

```cairo
#[derive(Copy, Drop)]
struct Monster {
    id: u8,
    tier: u8,
    beast_type: u8,
    level: u16,
    health: u32,
    max_health: u32,
    pos_x: u8,
    pos_y: u8,
    last_x: u8,
    last_y: u8,
    has_last_tile: bool,
    alive: bool,
    freeze_ticks: u8,
    shield: u32,
    spawn_tick: u16,
}
```

### SimulationState (runtime)

```cairo
struct SimulationState {
    rng_state: u32,
    current_tick: u16,
    monsters_escaped: u16,
    monsters_killed: u16,
    finished: bool,
    winner: u8,  // 0=draw, 1=defender, 2=attacker
}
```

---

## Enums

```cairo
#[derive(Copy, Drop, Serde, PartialEq)]
pub enum BeastType {
    Hunter,   // value: 1
    Magic,    // value: 2
    Brute,    // value: 3
}

#[derive(Copy, Drop, Serde, PartialEq)]
pub enum MatchStatus {
    AwaitingOpponent,
    InProgress,
    Completed,
    Cancelled,
}

#[derive(Copy, Drop, Serde, PartialEq)]
pub enum SimulationWinner {
    Draw,
    Defender,
    Attacker,
}
```

---

## Constants

```cairo
// Tower tier configs: (attack_speed, range, crit_chance_pct)
// attack_speed = ticks between attacks (T4 always fires)
const T1_ATTACK_SPEED: u8 = 2;
const T1_RANGE: u8 = 1;
const T2_ATTACK_SPEED: u8 = 1;
const T2_RANGE: u8 = 1;
const T3_ATTACK_SPEED: u8 = 1;
const T3_RANGE: u8 = 0;   // global
const T4_ATTACK_SPEED: u8 = 1;  // always fires (special case)
const T4_RANGE: u8 = 1;
const T5_ATTACK_SPEED: u8 = 2;
const T5_RANGE: u8 = 3;
const DEFAULT_CRIT_CHANCE: u8 = 20;  // 20%

// Monster tier configs: step_ticks
const T1_STEP_TICKS: u8 = 4;
const T2_STEP_TICKS: u8 = 1;
const T3_STEP_TICKS: u8 = 5;
const T4_STEP_TICKS: u8 = 1;  // 10% chance to move
const T5_STEP_TICKS: u8 = 3;

// Type chart multipliers (numerator, denominator)
// Advantage: 3/2 = 1.5x, Disadvantage: 1/2 = 0.5x, Neutral: 1/1 = 1.0x

// Game limits
const MAX_TICKS: u16 = 1000;
const MAX_TOWERS: u8 = 5;
const MAX_BEASTS: u8 = 5;
const MAX_GRID_SIZE: u8 = 32;
const MAX_PATH_LENGTH: u8 = 64;
const WAGER_FEE_PCT: u8 = 5;
const SWARM_COUNT: u8 = 4;
const SWARM_HEALTH_DIVISOR: u8 = 5;
const SHIELD_HEALTH_PCT: u8 = 50;
const T4_MOVE_CHANCE_PCT: u8 = 10;
const T4_TELEPORT_CHANCE_PCT: u8 = 10;
const T4_TELEPORT_TILES: u8 = 2;
```
