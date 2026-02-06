// =============================================================================
// Match Actions System — Interface Definition
// =============================================================================
// This is a DESIGN ARTIFACT, not compilable code. It defines the contract
// interface for match lifecycle management.
// =============================================================================

/// Match lifecycle management interface.
/// Handles match creation, joining, cancellation, and wager distribution.
/// Wagers use ERC20 tokens from the protocol-approved list.
#[starknet::interface]
trait IMatchActions<T> {
    /// Create a new match as Player 1.
    /// Player 1 submits BOTH their defender tower setup AND their attacker squad.
    /// Player must have approved the wager_token for transfer before calling.
    /// Wager is escrowed via ERC20 transfer_from.
    ///
    /// Parameters:
    /// - grid_id: u32 — ID of the map to play on
    /// - towers: Array<TowerInput> — P1's tower placements (for defending)
    /// - beasts: Array<BeastInput> — P1's attacker squad (for attacking in Round 2)
    /// - wager_token: ContractAddress — ERC20 token address for wager
    /// - wager_amount: u256 — amount to wager
    /// - budget: u32 — squad point budget for this match (both players must comply)
    ///
    /// Returns: match_id: u32
    ///
    /// Emits: MatchCreated { match_id, player1, grid_id, wager_token, wager_amount, budget }
    ///
    /// Reverts:
    /// - INVALID_GRID: grid_id not registered
    /// - EMPTY_SQUAD: towers or beasts array is empty
    /// - INVALID_TOWER_PLACEMENT: tower on path/blocked tile or out of bounds
    /// - DUPLICATE_TOWER_POSITION: two towers on same tile
    /// - SQUAD_OVER_BUDGET: total cost exceeds budget
    /// - ZERO_WAGER: wager_amount is 0
    /// - ZERO_BUDGET: budget is 0
    /// - TOKEN_NOT_APPROVED: wager_token not on approved list
    /// - TRANSFER_FAILED: ERC20 transfer_from failed (insufficient allowance/balance)
    fn create_match(
        ref self: T,
        grid_id: u32,
        towers: Array<TowerInput>,
        beasts: Array<BeastInput>,
        wager_token: ContractAddress,
        wager_amount: u256,
        budget: u32,
    ) -> u32;

    /// Join an existing match as Player 2.
    /// Player 2 submits BOTH their defender tower setup AND their attacker squad.
    /// Must approve the match's wager_token for the same wager_amount before calling.
    /// Both rounds execute immediately upon joining.
    ///
    /// Parameters:
    /// - match_id: u32 — ID of the match to join
    /// - towers: Array<TowerInput> — P2's tower placements (for defending in Round 2)
    /// - beasts: Array<BeastInput> — P2's attacker squad (for attacking in Round 1)
    ///
    /// Returns: MatchResultOutput struct
    ///
    /// Emits: MatchJoined, MatchResolved
    ///
    /// Reverts:
    /// - MATCH_NOT_FOUND: match_id doesn't exist
    /// - MATCH_NOT_AWAITING: match is not in AwaitingOpponent status
    /// - CANNOT_JOIN_OWN_MATCH: caller is player1 (FR-013)
    /// - SQUAD_OVER_BUDGET: P2's squad exceeds match budget
    /// - TRANSFER_FAILED: ERC20 transfer_from failed
    /// - (same tower/squad validation errors as create_match)
    fn join_match(
        ref self: T,
        match_id: u32,
        towers: Array<TowerInput>,
        beasts: Array<BeastInput>,
    ) -> MatchResultOutput;

    /// Cancel a match that hasn't been joined yet.
    /// Only callable by player1. Refunds the escrowed wager via ERC20 transfer.
    ///
    /// Emits: MatchCancelled { match_id }
    ///
    /// Reverts:
    /// - MATCH_NOT_FOUND
    /// - NOT_MATCH_CREATOR: caller is not player1
    /// - MATCH_NOT_AWAITING: match is not in AwaitingOpponent status
    fn cancel_match(ref self: T, match_id: u32);

    /// Get match details (view function).
    fn get_match(self: @T, match_id: u32) -> MatchView;
}

/// Output struct for match resolution
struct MatchResultOutput {
    match_id: u32,
    winner: ContractAddress,
    p1_attack_score: u16,    // beasts P1 got through in Round 2
    p1_defend_score: u16,    // beasts P1 killed in Round 1
    p2_attack_score: u16,    // beasts P2 got through in Round 1
    p2_defend_score: u16,    // beasts P2 killed in Round 2
    p1_net_score: i32,
    p2_net_score: i32,
}

/// View struct for match info
struct MatchView {
    match_id: u32,
    player1: ContractAddress,
    player2: ContractAddress,
    grid_id: u32,
    wager_token: ContractAddress,
    wager_amount: u256,
    budget: u32,
    status: u8,     // 0=AwaitingOpponent, 1=InProgress, 2=Completed, 3=Cancelled
    winner: ContractAddress,
}

// =============================================================================
// Match Resolution Logic (internal)
// =============================================================================
//
// Round 1: P1 defends (P1's towers) vs P2 attacks (P2's beasts)
//   → r1_result = simulation.run(seed, grid, p1_towers, p2_beasts, MAX_TICKS)
//
// Round 2: P2 defends (P2's towers) vs P1 attacks (P1's beasts)
//   → r2_result = simulation.run(seed + 1, grid, p2_towers, p1_beasts, MAX_TICKS)
//
// Scoring:
//   p1_net = r2_result.escaped - r1_result.escaped
//   p2_net = r1_result.escaped - r2_result.escaped
//   (positive net = good, you escaped more than your opponent escaped against you)
//
// Winner determination:
//   if p1_net > p2_net → player1 wins
//   if p2_net > p1_net → player2 wins
//   if tied → tiebreaker: player with fewer total squad points wins (FR spec)
//   if still tied → draw: both wagers refunded, no fee
//
// Payout (ERC20 transfers):
//   total_pot = wager_amount * 2
//   winner_payout = total_pot * 95 / 100
//   fee = total_pot - winner_payout  (avoids rounding dust loss)
//   token.transfer(winner, winner_payout)
//   token.transfer(fee_recipient, fee)
//   On draw: token.transfer(player1, wager_amount), token.transfer(player2, wager_amount)
