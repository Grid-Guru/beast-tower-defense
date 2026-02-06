// =============================================================================
// Squad Validation System — Interface Definition
// =============================================================================
// This is a DESIGN ARTIFACT, not compilable code. It defines the contract
// interface for squad composition validation and budget checking.
// =============================================================================

/// Squad validation interface.
/// Validates beast compositions, tower placements, and budget constraints.
#[starknet::interface]
trait ISquad<T> {
    /// Validate a squad of towers against a grid.
    /// Checks: positions valid, not on path/blocked, no duplicates, within budget.
    ///
    /// Parameters:
    /// - grid_id: u32 — the grid to validate against
    /// - towers: Array<TowerInput> — tower placements to validate
    /// - budget: u32 — maximum allowed total cost
    ///
    /// Returns: (valid: bool, total_cost: u32)
    ///
    /// Reverts on invalid input (bad tier, bad type, out of bounds).
    fn validate_towers(
        self: @T,
        grid_id: u32,
        towers: Array<TowerInput>,
        budget: u32,
    ) -> (bool, u32);

    /// Validate a squad of attacker beasts.
    /// Checks: valid tiers, valid types, within budget.
    ///
    /// Parameters:
    /// - beasts: Array<BeastInput> — attacker beasts to validate
    /// - budget: u32 — maximum allowed total cost
    ///
    /// Returns: (valid: bool, total_cost: u32)
    fn validate_beasts(
        self: @T,
        beasts: Array<BeastInput>,
        budget: u32,
    ) -> (bool, u32);

    /// Calculate the cost of a single beast.
    /// Formula: level + health (per design doc, exact formula TBD)
    ///
    /// Parameters:
    /// - level: u16
    /// - health: u32
    ///
    /// Returns: cost: u32
    fn beast_cost(self: @T, level: u16, health: u32) -> u32;
}

// =============================================================================
// Validation Rules (internal)
// =============================================================================
//
// Tower placement validation:
//   1. pos_x < grid.width && pos_y < grid.height
//   2. (pos_x, pos_y) is NOT a path tile
//   3. (pos_x, pos_y) is NOT a blocked tile
//   4. No two towers share (pos_x, pos_y)
//   5. tower.tier in {1, 2, 3, 4, 5}
//   6. tower.beast_type in {1, 2, 3} (Hunter, Magic, Brute)
//   7. tower.level > 0
//   8. tower.health > 0
//   9. towers.len() <= MAX_TOWERS
//
// Beast validation:
//   1. beast.tier in {1, 2, 3, 4, 5}
//   2. beast.beast_type in {1, 2, 3}
//   3. beast.level > 0
//   4. beast.health > 0
//   5. beasts.len() <= MAX_BEASTS
//
// Budget validation:
//   sum(beast_cost(b.level, b.health) for b in squad) <= budget
