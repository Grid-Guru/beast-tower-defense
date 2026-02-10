// =============================================================================
// Grid Models (Dojo persistent) — Pre-registered map definitions
// =============================================================================

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
