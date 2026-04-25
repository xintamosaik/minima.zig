/// The tile size will always be 8. For larger sprites we use 2x8 or 4x8 tiles, but the basic unit is 8 pixels.
/// This keeps calculations simple and close to retro aesthetics.
pub const TILE_SIZE: u32 = 8;
/// We use 16 tiles for now.
/// It's just a nice number that somewhat fits retro resolutions and allows for a simple grid-based world.
/// This means our world will be 128 pixels wide (16 tiles * 8 pixels per tile).
pub  const GRID_W: u32 = 16;
/// We use 12 tiles for now.
/// It's just a nice number that somewhat fits retro resolutions and allows for a simple grid-based world.
/// This means our world will be 96 pixels high (12 tiles * 8 pixels per tile).
pub const GRID_H: u32 = 12;

/// Flat tile storage; index is computed by `tileIndex`.
pub const GRID_LEN = GRID_W * GRID_H;
/// Tile types used by the world grid.
const TileKind = enum(u8) {
    light,
    dark,
    wall,
};

/// Converts tile coordinates to a linear index.
pub fn tileIndex(tx: u32, ty: u32) usize {
    return @as(usize, @intCast(ty * GRID_W + tx));
}

/// Sets one tile if coordinates are inside the grid.
pub fn setTile(tx: u32, ty: u32, kind: TileKind) void {
    if (tx >= GRID_W or ty >= GRID_H) return;
    world_tiles[tileIndex(tx, ty)] = kind;
}

pub fn getTile(tx: u32, ty: u32) TileKind {
   return world_tiles[tileIndex(tx, ty)];
}
/// Initial map data; `init()` overwrites this with a checkerboard.
var world_tiles: [GRID_LEN]TileKind = [_]TileKind{.dark} ** GRID_LEN;


// AFTER TILES
// AFTER TILES
// AFTER TILES