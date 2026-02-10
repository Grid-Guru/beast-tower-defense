// =============================================================================
// Admin System — Interface Definition
// =============================================================================
// This is a DESIGN ARTIFACT, not compilable code. It defines the contract
// interface for protocol administration.
// =============================================================================

/// Protocol administration interface.
/// All functions are restricted to the current admin address.
/// Admin is initially set to the deployer.
#[starknet::interface]
trait IAdmin<T> {
    /// Register a new map for use in matches.
    /// Only callable by admin. Map data is immutable after registration.
    ///
    /// Parameters:
    /// - grid_id: u32 — unique map identifier
    /// - width: u8 — grid width (1-32)
    /// - height: u8 — grid height (1-32)
    /// - path_tiles: Array<(u8, u8)> — ordered path tile coordinates
    /// - blocked_tiles: Array<(u8, u8)> — forbidden placement tiles
    /// - start_x: u8, start_y: u8 — monster spawn point
    /// - end_x: u8, end_y: u8 — monster escape point
    ///
    /// Emits: MapRegistered { grid_id, width, height }
    ///
    /// Reverts:
    /// - NOT_ADMIN: caller is not admin
    /// - GRID_ALREADY_EXISTS: grid_id already registered
    /// - INVALID_GRID_SIZE: width or height is 0 or > 32
    /// - INVALID_PATH: path is empty, start/end not on path, or path not connected
    /// - PATH_BLOCKED_OVERLAP: a tile appears in both path and blocked lists
    fn register_map(
        ref self: T,
        grid_id: u32,
        width: u8,
        height: u8,
        path_tiles: Array<(u8, u8)>,
        blocked_tiles: Array<(u8, u8)>,
        start_x: u8,
        start_y: u8,
        end_x: u8,
        end_y: u8,
    );

    /// Approve an ERC20 token for use as match wager.
    /// Only callable by admin.
    ///
    /// Emits: TokenApproved { token }
    ///
    /// Reverts:
    /// - NOT_ADMIN: caller is not admin
    /// - ZERO_ADDRESS: token is zero address
    fn approve_token(ref self: T, token: ContractAddress);

    /// Revoke an ERC20 token from the approved wager list.
    /// Does not affect in-progress matches using this token.
    /// Only callable by admin.
    ///
    /// Emits: TokenRevoked { token }
    ///
    /// Reverts:
    /// - NOT_ADMIN: caller is not admin
    fn revoke_token(ref self: T, token: ContractAddress);

    /// Set the protocol fee recipient address.
    /// Only callable by admin.
    ///
    /// Emits: FeeRecipientUpdated { new_fee_recipient }
    ///
    /// Reverts:
    /// - NOT_ADMIN: caller is not admin
    /// - ZERO_ADDRESS: new_fee_recipient is zero address
    fn set_fee_recipient(ref self: T, new_fee_recipient: ContractAddress);

    /// Transfer admin ownership to a new address.
    /// Only callable by current admin. Takes effect immediately.
    ///
    /// Emits: AdminTransferred { previous_admin, new_admin }
    ///
    /// Reverts:
    /// - NOT_ADMIN: caller is not admin
    /// - ZERO_ADDRESS: new_admin is zero address
    fn transfer_admin(ref self: T, new_admin: ContractAddress);

    /// Check if a token is approved for wagers (view function).
    fn is_token_approved(self: @T, token: ContractAddress) -> bool;

    /// Get admin config (view function).
    fn get_admin_config(self: @T) -> AdminConfigView;
}

/// View struct for admin info
struct AdminConfigView {
    admin: ContractAddress,
    fee_recipient: ContractAddress,
}
