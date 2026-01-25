# Beast Tower Defense - System Breakdown

A competitive tower defense game built around Loot Survivor BEASTs, where players wager and compete in asymmetric attack/defend rounds.

---

## 1. Map System

Pre-designed grids that players choose from when creating a match.

Each grid contains:
- **A path** from point A to point B (attackers traverse this)
- **Forbidden spaces** (no tower placement allowed)
- **Free spaces** (towers can be placed here)

---

## 2. Match System

| Phase | Player 1 (Creator) | Player 2 (Contender) |
|-------|-------------------|---------------------|
| Setup | Chooses grid → Places towers → Sets wager | Joins game → Places towers → Pays matching wager |
| Round 1 | Defender | Attacker |
| Round 2 | Attacker | Defender |

Both players experience both roles, ensuring balanced competition.

---

## 3. Squad Building System

### Budget Mechanic
Each player has a limited point pool to spend on beasts.

### Beast Cost Formula
Derived from `level + health` (exact formula TBD)

### Strategic Implications

| Beast Profile | Cost | Defending | Attacking |
|---------------|------|-----------|-----------|
| High level, low health | Cheap | Strong | Fragile |
| Low level, high health | Cheap | Weak | Tanky |
| High level, high health | Expensive | Strong | Tanky |

This system ensures that players with weaker beast collections can still compete through smart squad composition.

---

## 4. Beast Stat Usage

| Stat | Role as Defender (Tower) | Role as Attacker |
|------|--------------------------|------------------|
| **Health** | Unused | Endurance (damage capacity) |
| **Level** | Tower power (damage output) | Unused |
| **Tier** | Determines tower ability type | Determines vulnerability type |
| **Type** | Damage multiplier | Damage multiplier |
| **Power** | Unused | Unused |

> **Design Note:** Power is intentionally excluded to give utility to high-level T3/T4/T5 beasts that might otherwise be undervalued.

---

## 5. Type Advantage System

The classic Loot Survivor type triangle applies to combat:

```
    Hunter
     /    \
    /      \
Brute <--- Magic
```

- Hunter beats Magic
- Magic beats Brute
- Brute beats Hunter

Same damage multipliers as Loot Survivor.

---

## 6. Tier Ability System (Defense Mode)

Each tier has a distinct tower behavior when defending.

| Tier | Tower Behavior |
|------|----------------|
| T1 | Long range, slow fire rate |
| T2 | Short range, high damage |
| T3 | TBD |
| T4 | TBD |
| T5 | TBD |

*(Abilities to be expanded based on playtesting and balance)*

---

## 7. Tier Vulnerability System (Attack Mode)

When attacking, a beast's tier determines its weakness pattern, mirroring how that tier behaves as a tower.

**Example:**
> T1 towers fire from long range → T1 attackers take increased damage from long-distance shots

This creates interesting counter-play: knowing which tiers your opponent has placed as towers informs which tiers you want to send as attackers.

---

## 8. Combat Flow

```
┌─────────────────────────────────────────┐
│  Attacker beasts spawn at point A       │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  Beasts follow the path toward point B  │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  Defender towers fire based on          │
│  range/ability (determined by tier)     │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  Type matchups apply damage multipliers │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  Tier vulnerabilities modify damage     │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  Beasts surviving to point B = points   │
└─────────────────────────────────────────┘
```

---

## 9. Scoring & Win Condition

### Metrics

| Metric | Description |
|--------|-------------|
| Attack Score | Beasts that reached point B when attacking |
| Defense Score | Enemy beasts stopped when defending |
| **Balance** | Net score across both rounds |

### Determining the Winner

1. **Primary:** Highest balance wins
2. **Tiebreaker:** Player who spent fewer squad-building points wins

---

## 10. Economy

| Recipient | Percentage |
|-----------|------------|
| Winner | 95% of total pot |
| Fee | 5% |

Fee distribution TBD (options: developers, LS DAO, or split).

---

## Open Design Questions

### Gameplay
- How does attacker pathing work? Fixed path or AI-driven?
- Is combat real-time or discrete/turn-based?
- How many beasts per squad?
- Can towers be destroyed, or are they invulnerable?

### Balance
- Exact formula for beast point cost
- Damage calculations and multipliers
- Tier ability specifics for T3, T4, T5

### Technical
- Onchain vs offchain game logic
- If onchain (Cairo/Starknet): how to handle determinism and avoid real-time simulation
- Commit-reveal scheme for tower placement to prevent sniping?

### Economic
- Fee split between devs and LS DAO
- Minimum/maximum wager limits
- Anti-collusion measures

---

## Next Steps

1. Define exact tier abilities and balance formulas
2. Prototype a single map with basic combat
3. Playtest to find dominant strategies
4. Determine technical architecture (onchain scope)
5. Build MVP
