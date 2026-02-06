# Feature Specification: Provable On-Chain Simulation Engine

**Feature Branch**: `001-cairo-simulation-engine-contract`
**Created**: 2026-02-06
**Status**: Draft
**Input**: Create a provable on-chain version of the Beast Tower Defense simulation engine, enabling trustless competitive 1v1 matches with wagers.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Resolve a Battle Trustlessly (Priority: P1)

A game operator or player submits a battle configuration — a map, a set of defending towers, and a squad of attacking beasts — and the system executes the full battle deterministically on-chain. The same configuration always produces the same outcome. Both players can independently verify the result is fair and correct without trusting a server.

**Why this priority**: The provable battle engine is the foundation of the entire game. Without trustless, deterministic resolution, there is no competitive game and no basis for wagering. Every other feature (matches, economy, UI) depends on this engine producing verifiable results.

**Independent Test**: Submit a known battle configuration and verify the outcome (who won, how many beasts survived, how many escaped) is correct and repeatable.

**Acceptance Scenarios**:

1. **Given** a battle configuration with a map, towers, and beasts, **When** the battle is executed, **Then** the system produces a definitive result: winner (attacker, defender, or draw), number of beasts killed, number of beasts that escaped, and total rounds elapsed.
2. **Given** the exact same battle configuration, **When** the battle is executed multiple times, **Then** every execution produces an identical result.
3. **Given** a battle where no towers can reach any beasts, **When** the battle runs, **Then** all beasts escape and the attacker wins.
4. **Given** a battle where towers are overwhelmingly powerful, **When** the battle runs, **Then** all beasts are killed and the defender wins.
5. **Given** a battle configuration, **When** the result is compared against the existing reference simulation engine, **Then** both produce identical outcomes for the same inputs.

---

### User Story 2 - Compete in a 1v1 Wagered Match (Priority: P2)

Two players compete in a fair, asymmetric 1v1 match. Player 1 creates a match by selecting a map, placing their towers, choosing their attacker squad, and setting a wager. Player 2 joins by submitting their own tower layout and attacker squad, along with a matching wager. The system automatically runs two rounds — each player defends once and attacks once — then determines the overall winner and distributes the prize pool. Both players must commit their full setup upfront to prevent information advantage.

**Why this priority**: The match system is the competitive wrapper that makes the game playable. It enables the core loop of wagering, competing, and winning. However, it depends on a working battle engine (US1).

**Independent Test**: One player creates a match with a wager, a second player joins with a matching wager, both rounds execute automatically, and the winner receives their payout.

**Acceptance Scenarios**:

1. **Given** Player 1 submits a match with a map, towers, attacker beasts, and a wager amount, **When** the match is created, **Then** the wager is held in escrow and the match is listed as awaiting an opponent.
2. **Given** an open match, **When** Player 2 joins with their towers, attacker beasts, and a matching wager, **Then** Round 1 runs (Player 1 defends, Player 2 attacks) and Round 2 runs (Player 2 defends, Player 1 attacks).
3. **Given** both rounds are complete, **When** scores are compared, **Then** the player whose attackers escaped more beasts (net of what escaped against their defense) wins.
4. **Given** a completed match, **When** the winner is determined, **Then** the winner receives 95% of the total pot and 5% goes to the protocol as a fee.
5. **Given** a tied score, **When** the tiebreaker is applied, **Then** the player who spent fewer squad-building points wins.
6. **Given** an open match that hasn't been joined, **When** the creator cancels it, **Then** their escrowed wager is refunded in full.
7. **Given** a player tries to join their own match, **When** they attempt to join, **Then** the system rejects the action.

---

### User Story 3 - Build a Squad Within Budget (Priority: P3)

Players compose their battle squad — selecting which beasts serve as defending towers and which serve as attacking monsters — within a limited point budget. Each beast's cost is determined by its stats, creating strategic trade-offs: powerful beasts cost more, forcing players to balance quality vs. quantity. This prevents players with vastly stronger beast collections from auto-winning through raw stat advantage.

**Why this priority**: Budget constraints are what make the game competitively fair and strategically interesting. Without them, matches can still run (US1 + US2), but a player with higher-stat beasts would always dominate. This can be layered on after the core match flow exists.

**Independent Test**: Submit squad compositions of varying total cost against a fixed budget and verify that over-budget squads are rejected while valid squads are accepted.

**Acceptance Scenarios**:

1. **Given** a squad whose total cost exceeds the allowed budget, **When** the player attempts to use it in a match, **Then** the system rejects it with a clear error.
2. **Given** a squad whose total cost is within the allowed budget, **When** the player submits it, **Then** the squad is accepted.
3. **Given** a beast with known stats, **When** its cost is calculated, **Then** the cost equals the sum of its level and health values.
4. **Given** two squads with the same total cost but different compositions, **When** used in separate matches with the same opponent, **Then** the outcomes may differ based on the type/tier matchups, demonstrating that strategy matters beyond raw stats.

---

### Edge Cases

- What happens when a battle exceeds the maximum number of rounds? The system should force-end the battle and determine a winner based on the current score.
- What happens when a player submits an empty squad (no beasts)? The system should reject the submission.
- What happens when towers are placed on the path or on forbidden spaces? The system should reject the placement.
- What happens when a player tries to join their own match? The system should reject the action.
- What happens when beasts of the same tier interact (e.g., T3 swarm beasts splitting into 4 copies)? The system should handle spawning mechanics consistently with the reference engine.
- What happens if a map has no valid route from start to end? The system should reject it at map registration time.
- What happens on a draw with identical squad costs? The match should end as a true draw with wagers refunded to both players.

## Requirements *(mandatory)*

### Functional Requirements

**Battle Engine**

- **FR-001**: The system MUST execute battles deterministically — the same inputs always produce the same outputs, regardless of when or how many times the battle is run.
- **FR-002**: The system MUST implement all five tower defense ability types, matching the behavior defined in the reference simulation engine:
  - Tier 1: Freezing ability (slows attackers, scales with beast level)
  - Tier 2: Area-of-effect burst damage
  - Tier 3: Global damage (hits all attackers)
  - Tier 4: Rapid double-shot targeting the furthest attacker
  - Tier 5: Tank-buster targeting the toughest attacker
- **FR-003**: The system MUST implement all five attacker behavior types:
  - Tier 1: Slow movement
  - Tier 2: Fast movement
  - Tier 3: Splits into 4 weaker copies (swarm)
  - Tier 4: Unpredictable movement with teleportation chance
  - Tier 5: Damage-absorbing shield plus moderate speed
- **FR-004**: The system MUST apply the Loot Survivor type advantage triangle (Hunter beats Magic, Magic beats Brute, Brute beats Hunter) with correct damage multipliers (1.5x advantage, 0.5x disadvantage, 1.0x neutral).
- **FR-005**: The system MUST support critical hits at 20% base chance, doubling the effect (damage or freeze duration).
- **FR-006**: The system MUST produce verifiable results that can be compared against the existing reference engine output for validation.

**Match System**

- **FR-007**: The system MUST allow a player to create a match by selecting a map, placing towers, choosing attacker beasts, and setting a wager amount.
- **FR-008**: The system MUST hold wagers in escrow until the match is resolved or cancelled.
- **FR-009**: The system MUST allow a second player to join an open match by submitting their own setup and a matching wager.
- **FR-010**: The system MUST execute two rounds per match with role swapping (each player defends once and attacks once) and determine an overall winner.
- **FR-011**: The system MUST distribute 95% of the total pot to the winner and 5% as a protocol fee.
- **FR-012**: The system MUST allow match creators to cancel open (unjoined) matches and receive a full wager refund.
- **FR-013**: The system MUST prevent a player from joining their own match.
- **FR-014**: The system MUST require both players to commit their full setup (towers AND attacker squad) upfront, before seeing the opponent's choices.

**Validation**

- **FR-015**: The system MUST validate that towers are placed only on free spaces (not on the path, not on forbidden tiles, within map boundaries).
- **FR-016**: The system MUST validate that no two towers occupy the same space.
- **FR-017**: The system MUST validate squad compositions against the point budget and reject over-budget squads.
- **FR-018**: The system MUST reject squads with invalid beast data (invalid tier, invalid type, zero health, zero level, empty squad).

**Results & Auditability**

- **FR-019**: The system MUST store match results permanently for verifiability and auditability.
- **FR-020**: The system MUST emit structured notifications for key battle events (spawns, attacks, kills, escapes, match results) to enable replay viewers and analytics.

### Key Entities

- **Beast**: A Loot Survivor creature with a unique identity. Key attributes: tier (1-5, determines ability), type (Hunter/Magic/Brute, determines matchup advantages), level (determines power as a tower), health (determines endurance as an attacker).
- **Map**: A pre-designed game board with a defined path from start to end, forbidden spaces where towers cannot be placed, and free spaces for tower placement. Maps are fixed and selected by players when creating a match.
- **Match**: A competitive 1v1 session between two players. Contains the selected map, both players' setups, wager amount, status (awaiting opponent / in progress / completed / cancelled), and the final result.
- **Player Setup**: A player's complete battle configuration for a match — which beasts are placed as towers (and where), and which beasts are sent as attackers.
- **Match Result**: The recorded outcome of a completed match — per-round scores (beasts killed and escaped), net scores, and the overall winner.

## Assumptions

- Beast stats (tier, type, level, health) are provided as inputs at match creation. On-chain verification of beast NFT ownership is deferred to a future feature.
- Maps are pre-registered by game operators. Player-created maps are out of scope.
- The beast cost formula is `level + health`. This may be adjusted after playtesting.
- Maximum squad size is 5 towers and 5 attacker beasts per player.
- Both players submit ALL of their setup (towers + attackers) in a single action, eliminating the need for a commit-reveal scheme.
- Draws where both squad costs are also equal result in full wager refunds to both players.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For any given battle configuration, the on-chain engine and the reference simulation engine produce identical outcomes (same winner, same kills, same escapes, same round count).
- **SC-002**: All 5 tower ability types behave correctly in at least 3 distinct test scenarios each, covering normal operation, critical hits, and type advantage interactions.
- **SC-003**: All 5 attacker behavior types behave correctly in at least 3 distinct test scenarios each, including edge cases (swarm splitting, shield absorption, teleportation).
- **SC-004**: A full match (create, join, 2 rounds, winner determination, payout) completes successfully end-to-end in under 30 seconds.
- **SC-005**: A typical battle (5 towers vs. 5 attackers, ~100 rounds) completes within the system's per-operation resource limits.
- **SC-006**: Type advantage calculations produce the correct multiplier for all 9 type combinations (3 attacker types x 3 defender types).
- **SC-007**: Invalid inputs (over-budget squads, invalid placements, empty squads, self-joins) are rejected with clear, specific error messages in 100% of cases.
- **SC-008**: Match payouts distribute exactly 95% to the winner and 5% to the protocol, with no rounding loss exceeding 1 unit of the smallest currency denomination.
