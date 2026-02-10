use starknet::ContractAddress;
use beast_td::models::admin::AdminConfigView;

#[starknet::interface]
pub trait IAdmin<T> {
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
    fn approve_token(ref self: T, token: ContractAddress);
    fn revoke_token(ref self: T, token: ContractAddress);
    fn set_fee_recipient(ref self: T, new_fee_recipient: ContractAddress);
    fn transfer_admin(ref self: T, new_admin: ContractAddress);
    fn is_token_approved(self: @T, token: ContractAddress) -> bool;
    fn get_admin_config(self: @T) -> AdminConfigView;
}

#[dojo::contract]
pub mod admin {
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;
    use starknet::{ContractAddress, get_caller_address};
    use core::num::traits::Zero;
    use beast_td::models::admin::{AdminConfig, ApprovedToken, AdminConfigView};
    use beast_td::models::grid::{GameGrid, GridPathTile, GridBlockedTile};
    use beast_td::events::{
        MapRegistered, TokenApproved, TokenRevoked, AdminTransferred, FeeRecipientUpdated,
    };
    use beast_td::utils::constants::{ADMIN_CONFIG_ID, MAX_GRID_SIZE, errors};
    use super::IAdmin;

    #[abi(embed_v0)]
    impl AdminImpl of IAdmin<ContractState> {
        fn register_map(
            ref self: ContractState,
            grid_id: u32,
            width: u8,
            height: u8,
            path_tiles: Array<(u8, u8)>,
            blocked_tiles: Array<(u8, u8)>,
            start_x: u8,
            start_y: u8,
            end_x: u8,
            end_y: u8,
        ) {
            let mut world = self.world_default();
            self.assert_admin(@world);

            // Validate grid doesn't exist
            let existing: GameGrid = world.read_model(grid_id);
            assert(existing.width == 0, errors::GRID_ALREADY_EXISTS);

            // Validate dimensions
            assert(width > 0 && width <= MAX_GRID_SIZE, errors::INVALID_GRID_SIZE);
            assert(height > 0 && height <= MAX_GRID_SIZE, errors::INVALID_GRID_SIZE);

            // Validate path not empty
            assert(path_tiles.len() > 0, errors::INVALID_PATH);

            // Validate start/end within bounds
            assert(start_x < width && start_y < height, errors::INVALID_PATH);
            assert(end_x < width && end_y < height, errors::INVALID_PATH);

            // Check start and end are on path
            let path_span = path_tiles.span();
            let mut start_on_path = false;
            let mut end_on_path = false;
            let mut i: u32 = 0;
            while i < path_span.len() {
                let (px, py) = *path_span.at(i);
                if px == start_x && py == start_y {
                    start_on_path = true;
                }
                if px == end_x && py == end_y {
                    end_on_path = true;
                }
                i += 1;
            };
            assert(start_on_path && end_on_path, errors::INVALID_PATH);

            // Check no path/blocked overlap
            let blocked_span = blocked_tiles.span();
            let mut pi: u32 = 0;
            while pi < path_span.len() {
                let (px, py) = *path_span.at(pi);
                let mut bi: u32 = 0;
                while bi < blocked_span.len() {
                    let (bx, by) = *blocked_span.at(bi);
                    assert(!(px == bx && py == by), errors::PATH_BLOCKED_OVERLAP);
                    bi += 1;
                };
                pi += 1;
            };

            // Write grid
            let path_count: u8 = path_span.len().try_into().unwrap();
            let blocked_count: u8 = blocked_span.len().try_into().unwrap();

            world
                .write_model(
                    @GameGrid {
                        grid_id, width, height, start_x, start_y, end_x, end_y, path_count,
                        blocked_count,
                    },
                );

            // Write path tiles
            let mut i: u8 = 0;
            while i < path_count {
                let (px, py) = *path_span.at(i.into());
                world.write_model(@GridPathTile { grid_id, index: i, x: px, y: py });
                i += 1;
            };

            // Write blocked tiles
            let mut i: u8 = 0;
            while i < blocked_count {
                let (bx, by) = *blocked_span.at(i.into());
                world.write_model(@GridBlockedTile { grid_id, index: i, x: bx, y: by });
                i += 1;
            };

            world.emit_event(@MapRegistered { grid_id, width, height });
        }

        fn approve_token(ref self: ContractState, token: ContractAddress) {
            let mut world = self.world_default();
            self.assert_admin(@world);
            assert(!token.is_zero(), errors::ZERO_ADDRESS);

            world.write_model(@ApprovedToken { token, approved: true });
            world.emit_event(@TokenApproved { token, approved: true });
        }

        fn revoke_token(ref self: ContractState, token: ContractAddress) {
            let mut world = self.world_default();
            self.assert_admin(@world);

            world.write_model(@ApprovedToken { token, approved: false });
            world.emit_event(@TokenRevoked { token, revoked: true });
        }

        fn set_fee_recipient(ref self: ContractState, new_fee_recipient: ContractAddress) {
            let mut world = self.world_default();
            self.assert_admin(@world);
            assert(!new_fee_recipient.is_zero(), errors::ZERO_ADDRESS);

            let config: AdminConfig = world.read_model(ADMIN_CONFIG_ID);
            world
                .write_model(
                    @AdminConfig {
                        config_id: ADMIN_CONFIG_ID,
                        admin: config.admin,
                        fee_recipient: new_fee_recipient,
                    },
                );
            world.emit_event(@FeeRecipientUpdated { new_fee_recipient, updated: true });
        }

        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            let mut world = self.world_default();
            self.assert_admin(@world);
            assert(!new_admin.is_zero(), errors::ZERO_ADDRESS);

            let config: AdminConfig = world.read_model(ADMIN_CONFIG_ID);
            let previous_admin = config.admin;
            world
                .write_model(
                    @AdminConfig {
                        config_id: ADMIN_CONFIG_ID,
                        admin: new_admin,
                        fee_recipient: config.fee_recipient,
                    },
                );
            world.emit_event(@AdminTransferred { previous_admin, new_admin });
        }

        fn is_token_approved(self: @ContractState, token: ContractAddress) -> bool {
            let world = self.world_default();
            let approved_token: ApprovedToken = world.read_model(token);
            approved_token.approved
        }

        fn get_admin_config(self: @ContractState) -> AdminConfigView {
            let world = self.world_default();
            let config: AdminConfig = world.read_model(ADMIN_CONFIG_ID);
            AdminConfigView { admin: config.admin, fee_recipient: config.fee_recipient }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"beast_td")
        }

        fn assert_admin(self: @ContractState, world: @dojo::world::WorldStorage) {
            let config: AdminConfig = world.read_model(ADMIN_CONFIG_ID);
            assert(get_caller_address() == config.admin, errors::NOT_ADMIN);
        }
    }
}
