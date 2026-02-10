# Research: Cairo Simulation Engine Contract

**Branch**: `001-cairo-simulation-engine-contract`
**Date**: 2026-02-06
**Status**: Complete

## Research Topics & Decisions

### 1. Dojo Framework Architecture

**Decision**: Use Dojo's ECS (Entity-Component-System) framework for on-chain game state management.

**Rationale**: Dojo is purpose-built for provable on-chain games on Starknet. It provides:
- `#[dojo::model]` macro for defining persistent game state as Cairo structs with `#[key]` attributes
- `#[dojo::contract]` macro for system contracts that read/write models via `world.read_model()` / `world.write_model()`
- Automatic event emission for model changes (indexed by Torii)
- `spawn_test_world` helper for deterministic testing
- `sozo build`, `sozo test`, `sozo migrate` toolchain for development

**Alternatives considered**:
- Raw Starknet contracts without Dojo: More control but requires building state management, event indexing, and testing infrastructure from scratch. Rejected — Dojo solves all of these.
- Alternative game frameworks (MUD on Ethereum): Wrong chain. The project targets Starknet/Cairo.

**Key Dojo patterns**:
```cairo
// Model definition
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Position {
    #[key]
    pub entity_id: u32,
    pub x: u32,
    pub y: u32,
}

// System contract
#[dojo::contract]
mod actions {
    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn do_action(ref self: ContractState) {
            let mut world = self.world(@"beast_td");
            let model: Position = world.read_model(entity_id);
            world.write_model(@new_position);
        }
    }
}
```

---

### 2. Deterministic PRNG in Cairo

**Decision**: Implement Mulberry32 PRNG using Cairo's `u32` wrapping arithmetic.

**Rationale**: The canonical JS engine uses Mulberry32 — a fast 32-bit PRNG with good distribution. Cairo supports `u32` natively and has wrapping arithmetic operations. The algorithm translates directly:

**JS Reference**:
```javascript
state = (state + 0x6D2B79F5) | 0;
let t = Math.imul(state ^ (state >>> 15), 1 | state);
t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
```

**Cairo Translation Strategy**:
- `| 0` → wrapping add (implicit in u32)
- `Math.imul(a, b)` → `core::integer::u32_wrapping_mul(a, b)` or just `a * b` with wrapping
- `>>> n` → `a / pow2(n)` (unsigned right shift via division by power of 2)
- Division by `4294967296` for [0,1) range → not needed; instead return raw u32 and use modular arithmetic for "random int" and "chance" operations
- `getRandomInt(max)` → `rng_next() % max`
- `chance(prob)` → `rng_next() % 100 < (prob * 100)` (e.g., 20% → `rng_next() % 100 < 20`)

**Alternatives considered**:
- Pedersen hash-based RNG: More "crypto-native" but would break determinism compatibility with the JS reference engine. Rejected.
- VRF (Verifiable Random Function): Off-chain randomness, defeats the purpose of on-chain determinism for replay. Rejected for simulation, but could be used for match seed generation.
- Sin-based PRNG (from .jsx): Poor distribution, not the canonical choice. Rejected.

---

### 3. Fixed-Point Arithmetic for Multipliers

**Decision**: Use integer arithmetic with explicit numerator/denominator pairs. No fixed-point library needed.

**Rationale**: The only non-integer math in the simulation is:
- Type multipliers: 0.5x, 1.0x, 1.5x
- Damage formulas: `level / 10`, `level / 100`
- Crit multiplier: 2x (already integer)

All of these can be expressed as `(value * numerator) / denominator`:
- 0.5x = `(value * 1) / 2` → equivalent to `value / 2`
- 1.0x = `value` (no-op)
- 1.5x = `(value * 3) / 2`
- `Math.ceil(a / b)` = `(a + b - 1) / b`
- `level / 10` with ceil = `(level + 9) / 10`

**Alternatives considered**:
- Fixed-point library (e.g., 18-decimal): Overkill for 3 multiplier values. Adds unnecessary complexity and gas cost. Rejected.
- Basis points (multiply everything by 10000): Unnecessarily large numbers. Rejected.

---

### 4. Simulation Execution Model

**Decision**: Execute the full simulation in a single transaction. No per-tick storage writes.

**Rationale**: The simulation engine processes up to `maxTicks` iterations of: spawn → attack → move → cleanup → win check. Writing to Dojo storage every tick would be prohibitively expensive (storage writes are the main gas cost on Starknet). Instead:
- All simulation state (towers, monsters, queue, counters) lives in function-local memory during execution
- Only the final result is written to the Dojo World: match outcome, scores, tick count
- Events are emitted during simulation for Torii indexing (zero storage cost, indexed off-chain)

**Gas estimation**: A 100-tick simulation with 5 towers and 5 beasts involves ~500 iterations of per-monster logic and ~500 iterations of per-tower logic. This is well within Starknet's compute limits (steps), especially since there are no storage reads/writes per tick.

**Alternatives considered**:
- Multi-transaction simulation (commit tick-by-tick): Would require storing full intermediate state. Rejected — far too expensive and complex.
- Off-chain simulation with STARK proof: Possible in theory but requires a separate prover infrastructure. Future optimization, not MVP. Rejected for now.

---

### 5. Match Lifecycle & Wager System

**Decision**: ERC20 escrow pattern — match creator selects a token from the protocol-approved list. Wager locked on create via `transfer_from`, matched on join, distributed on resolution.

**Rationale**:
- `create_match`: Player 1 approves the contract, then calls `create_match` with wager token address and amount. Contract calls `token.transfer_from(caller, contract, amount)`.
- `join_match`: Player 2 approves the same token, then joins. Contract calls `token.transfer_from(caller, contract, amount)` for the matching wager.
- Resolution: Winner receives 95% via `token.transfer(winner, payout)`. Protocol receives 5% via `token.transfer(fee_recipient, fee)`.
- Cancellation: Full refund via `token.transfer(player1, wager)`.

Both players must submit BOTH their tower placement AND their attacker squad upfront (before seeing the opponent's setup). This eliminates the need for commit-reveal for tower placement.

**Token approval**: The contract maintains an `ApprovedToken` model. Only tokens on the approved list can be used for wagers. Admin can add/remove tokens.

**Alternatives considered**:
- Native ETH value (payable functions): Starknet doesn't have native ETH payable the same way Ethereum does; ETH is an ERC20 on Starknet. Using ERC20 dispatcher is the standard pattern. No downside.
- Any-token (no approved list): Risk of spam tokens, rug-pull tokens, or non-standard ERC20s. Approved list provides operator curation. Selected per spec clarification Q1.

---

### 6. Grid Storage Strategy

**Decision**: Pre-register grid definitions as Dojo models. Path tiles stored as separate indexed models.

**Rationale**: Grids are static, defined by the game designers. They don't change during gameplay. Storing them as Dojo models allows:
- Multiple grid options for map selection
- On-chain validation of tower placement
- Path tile iteration during simulation

**Path tile storage**: Since Cairo doesn't have dynamic arrays in storage efficiently, path tiles and blocked tiles are stored as separate `GridPathTile` / `GridBlockedTile` models keyed by `(grid_id, index)`. The `GameGrid` model stores `path_count` and `blocked_count` to know how many tiles to read.

For MVP, a reasonable max path length (e.g., 64 tiles) is enforced.

---

### 7. Testing Strategy

**Decision**: Three-tier testing approach using `sozo test`.

**Rationale**:
1. **Unit tests**: Individual functions (RNG, type chart, damage calc, movement logic) tested in isolation with known inputs/outputs.
2. **Tier tests**: Each tower tier and monster tier gets dedicated tests with controlled scenarios (e.g., "T1 tower freezes exactly 2 monsters at level 40 with seed X").
3. **Regression tests**: Full simulation runs with configs and seeds that have known outputs from the JS reference engine. Assert exact match on winner, kills, escapes, tick count.

The `spawn_test_world` Dojo helper enables integration tests that deploy a test World and exercise the full contract flow.

---

### 8. Event Emission for Indexing

**Decision**: Emit Dojo events for key simulation milestones. Detailed per-tick events emitted as custom events.

**Rationale**: Torii (Dojo's indexer) automatically indexes `#[dojo::event]` emissions. The client needs:
- Match created/joined/resolved/cancelled events (for lobby UI)
- Simulation result events (for result display)
- Per-tick combat events are optional for replay visualization (can be emitted as custom events and indexed by Torii)

**Event types**:
- `MatchCreated { match_id, player1, grid_id, wager_token, wager_amount, budget }`
- `MatchJoined { match_id, player2 }`
- `MatchResolved { match_id, winner, p1_score, p2_score }`
- `MatchCancelled { match_id }`
- `SimulationTick { match_id, round, tick, event_type, data }` (for replay)

---

### 9. Mapping JS Engine Divergences

**Decision**: Follow SimulationEngine.js (canonical) for all mechanics. Document .jsx divergences as "not implemented."

**Rationale**: The two JS engines diverge in several ways. The canonical .js is the reference:

| Mechanic | .js (Canonical → Cairo) | .jsx (Not Implemented) |
|---|---|---|
| PRNG | Mulberry32 | sin-based |
| Distance | Manhattan | Chebyshev |
| Pathing | 4-directional | 8-directional |
| T4 teleport | 2 tiles | 3 tiles |
| T1 freeze | Math.ceil(duration * multiplier) | No ceil |
| Shield | Absorbs all (remaining damage → 0) | Pass-through excess |
| T3 spawn | 1 queue entry → 4 simultaneous spawns | 4 queue entries |
| Tiebreaker | Draw | Health-pool comparison |
| Logging | Minimal | tick_start/tick_end + query methods |

---

### 10. Beast NFT Integration

**Decision**: Accept beast stats as input parameters. No on-chain NFT ownership verification in MVP.

**Rationale**: The simulation engine only needs beast stats (id, name, tier, type, level, health) to execute. NFT ownership verification (checking Loot Survivor contract) can be added as a separate validation layer. For MVP, the contract trusts the submitted stats.

**Future**: Add `assert(owner_of(beast_id) == caller)` by reading from the Loot Survivor contract.

**Alternatives considered**:
- Full NFT integration in MVP: Requires cross-contract calls to Loot Survivor, adds complexity and external dependency. Rejected for MVP.

---

### 11. ERC20 Token Escrow Pattern

**Decision**: Use OpenZeppelin's `IERC20Dispatcher` for all token operations. Require ERC20 `approve` before `create_match`/`join_match`.

**Rationale**: On Starknet, all tokens (including ETH and STRK) are ERC20 contracts. The standard pattern is:
1. Player calls `token.approve(game_contract, amount)` before match creation/join
2. Contract calls `token.transfer_from(player, self, amount)` to escrow
3. On resolution, contract calls `token.transfer(winner, payout)` and `token.transfer(fee_recipient, fee)`
4. On cancellation, contract calls `token.transfer(player1, wager)`

The `IERC20Dispatcher` from OpenZeppelin Cairo Contracts provides type-safe cross-contract calls:
```cairo
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

let token = IERC20Dispatcher { contract_address: wager_token };
token.transfer_from(caller, self_address, amount);
```

**Key considerations**:
- No re-entrancy risk: Cairo/Starknet's execution model is sequential within a transaction
- Fee rounding: `winner_payout = total_pot * 95 / 100`, `fee = total_pot - winner_payout` (ensures no dust loss)
- Draws: Both players refunded in full, no fee charged

---

### 12. Single Admin Governance Model

**Decision**: Single admin address (deployer) with transferable ownership. No multi-sig, no timelock, no DAO.

**Rationale**: Per spec clarification Q3, a single admin is sufficient for MVP. The admin controls:
- `register_map(grid_id, width, height, path_tiles, blocked_tiles, start, end)` — add new maps
- `approve_token(token_address)` — add token to approved wager list
- `revoke_token(token_address)` — remove token from approved list
- `set_fee_recipient(address)` — change protocol fee recipient
- `transfer_admin(new_admin)` — transfer admin ownership

All admin functions check `assert(caller == admin_config.admin)`.

The `AdminConfig` is a singleton Dojo model (keyed by a constant, e.g., `config_id = 1`):
```cairo
#[dojo::model]
struct AdminConfig {
    #[key]
    config_id: u8,  // always 1
    admin: ContractAddress,
    fee_recipient: ContractAddress,
}
```

**Alternatives considered**:
- Multi-sig governance: Adds complexity, unnecessary for MVP. Can upgrade later.
- Ownable pattern (OpenZeppelin): Viable but Dojo's model system already handles storage. A simple model + assert is cleaner than importing the Ownable component.

---

### 13. Per-Match Squad Budget

**Decision**: Squad budget is set per-match by the creator. Both players are validated against the same budget.

**Rationale**: Per spec clarification Q4, the match creator chooses the budget when creating a match. This enables:
- Casual matches with high budgets (fewer constraints)
- Competitive matches with tight budgets (more strategic depth)
- Tournament organizers can standardize budgets per event

The budget is stored as a `u32` field on the `Match` model. Both `create_match` and `join_match` validate that `sum(beast_cost(b))` for towers + beasts <= budget.

**Beast cost formula**: `cost = level + health` (per spec assumptions). Stored as assumption, may be adjusted post-playtesting.

**Alternatives considered**:
- Protocol-wide fixed budget: Inflexible, removes player agency. Rejected per clarification.
- No budget (honor system): Defeats the purpose of competitive fairness. Rejected.
