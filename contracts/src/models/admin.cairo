use starknet::ContractAddress;

// =============================================================================
// Admin Config — Singleton model for protocol governance
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AdminConfig {
    #[key]
    pub config_id: u8, // always 1
    pub admin: ContractAddress,
    pub fee_recipient: ContractAddress,
}

// =============================================================================
// Approved Token — Tracks which ERC20 tokens can be used for wagers
// =============================================================================

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ApprovedToken {
    #[key]
    pub token: ContractAddress,
    pub approved: bool,
}

// =============================================================================
// View struct for admin info
// =============================================================================

#[derive(Copy, Drop, Serde)]
pub struct AdminConfigView {
    pub admin: ContractAddress,
    pub fee_recipient: ContractAddress,
}
