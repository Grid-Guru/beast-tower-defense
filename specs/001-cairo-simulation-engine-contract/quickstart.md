# Quickstart: Cairo Simulation Engine Contract

## Prerequisites

- **Dojo** (latest stable): Install via `curl -L https://install.dojoengine.org | bash && dojoup`
- **Scarb**: Bundled with Dojo installation
- **Sozo**: Bundled with Dojo installation
- **Katana**: Bundled with Dojo installation (local Starknet sequencer)
- **Torii**: Bundled with Dojo installation (indexer)

Verify installation:
```bash
sozo --version
katana --version
torii --version
```

## Project Setup

### 1. Initialize Dojo Project

```bash
# From repository root
mkdir -p contracts/src/{models,systems,utils}
mkdir -p contracts/tests
```

### 2. Configure Scarb.toml

```toml
[package]
name = "beast_td"
version = "0.1.0"
cairo-version = "2.9.1"

[dependencies]
dojo = { git = "https://github.com/dojoengine/dojo" }

[[target.dojo]]
```

### 3. Configure dojo_dev.toml

```toml
[world]
name = "Beast Tower Defense"

[namespace]
default = "beast_td"

[env]
rpc_url = "http://localhost:5050/"

[writers]
"beast_td" = ["beast_td-simulation", "beast_td-match_actions", "beast_td-squad"]
```

## Development Workflow

### Build

```bash
cd contracts && sozo build
```

### Test

```bash
cd contracts && sozo test
```

### Local Development (3 terminals)

**Terminal 1 — Local Sequencer:**
```bash
cd contracts && katana --config katana.toml
```

**Terminal 2 — Deploy:**
```bash
cd contracts && sozo build && sozo migrate
```

**Terminal 3 — Indexer:**
```bash
cd contracts && torii --config torii_dev.toml
```

## Key Implementation Notes

### No Floating Point
All JS `Math.ceil(a / b)` → Cairo `(a + b - 1) / b`
All 1.5x multipliers → `(value * 3) / 2`
All 0.5x multipliers → `value / 2`

### PRNG
Mulberry32 uses `u32` wrapping arithmetic. Use `core::num::traits::WrappingAdd` and `core::num::traits::WrappingMul`.

### Simulation Runs In-Memory
The full tick loop executes within a single function call. No intermediate storage writes. Only the final `MatchResult` is persisted via `world.write_model()`.

### Testing Against JS Reference
Generate reference outputs by running `SimulationEngine.js` with known configs and seeds, then assert Cairo produces identical results in `sozo test`.

## File Structure

```
contracts/
├── src/
│   ├── lib.cairo
│   ├── models/
│   │   ├── beast.cairo
│   │   ├── grid.cairo
│   │   ├── match_state.cairo
│   │   └── simulation.cairo
│   ├── systems/
│   │   ├── simulation.cairo
│   │   ├── match_actions.cairo
│   │   └── squad.cairo
│   ├── utils/
│   │   ├── rng.cairo
│   │   ├── math.cairo
│   │   └── constants.cairo
│   └── events.cairo
├── tests/
│   ├── test_rng.cairo
│   ├── test_type_chart.cairo
│   ├── test_tower_tiers.cairo
│   ├── test_monster_tiers.cairo
│   ├── test_simulation.cairo
│   ├── test_match.cairo
│   └── test_squad.cairo
├── Scarb.toml
├── dojo_dev.toml
└── katana.toml
```
