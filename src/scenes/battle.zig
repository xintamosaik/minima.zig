const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const font = @import("../font.zig");
const ui = @import("../ui.zig");
const patterns_outside = @import("../patterns_outside.zig");
const patterns_general = @import("../patterns_general.zig");
const plain = @import("../maps/battle/plain.zig");

const TILE_SIZE: u32 = 8;
const WIDTH: u32 = 40;
const HEIGHT: u32 = 25;
const LENGTH = WIDTH * HEIGHT;

const TileKind = enum(u8) { wall, water, grass, dirt, stone, empty };
/// Initial map data; `init()` overwrites this with a checkerboard.
var world_tiles: [LENGTH]TileKind = [_]TileKind{.empty} ** LENGTH;

/// Converts tile coordinates to a linear index.
fn tileIndex(tx: u32, ty: u32) usize {
    return @as(usize, @intCast(ty * WIDTH + tx));
}
/// Sets one tile if coordinates are inside the
fn setTile(tx: u32, ty: u32, kind: TileKind) void {
    if (tx >= WIDTH or ty >= HEIGHT) return;
    world_tiles[tileIndex(tx, ty)] = kind;
}
/// Sets one tile if the index is inside the
fn setTileRaw(index: u32, kind: TileKind) void {
    if (index >= LENGTH) {
        return;
    }
    world_tiles[index] = kind;
}
/// Gets the kind of a tile
fn getTile(tx: u32, ty: u32) TileKind {
    return world_tiles[tileIndex(tx, ty)];
}

/// Gets the kind of a tile with the index
fn getTileRaw(index: u32) TileKind {
    if (index >= LENGTH) {
        return .stone;
    }
    return world_tiles[index];
}

const BG = colors.C64_BLACK;

const Cursor = struct { now: u32, former: u32, last_move: u32 };

var cursor = Cursor{ .now = 0, .former = 0, .last_move = 0 };

const TileMapping = struct {
    base: TileKind,
    a: TileKind,
    b: TileKind,
};

const PatternMap = struct {
    a: [24]u32,
    b: [24]u32,
};

fn bitAt(rows: [24]u32, x: u32, y: u32) bool {
    const row = rows[y];
    const shift: u5 = @intCast(31 - x);
    return ((row >> shift) & 1) != 0;
}

fn loadMap(map: PatternMap, mapping: TileMapping) void {
    var y: u32 = 0;
    while (y < 24) : (y += 1) {
        var x: u32 = 0;
        while (x < 32) : (x += 1) {
            const kind =
                if (bitAt(map.b, x, y)) mapping.b else if (bitAt(map.a, x, y)) mapping.a else mapping.base;

            setTile(x, y, kind);
        }
    }
}
const tile_mapping = TileMapping{
    .base = .empty,
    .a = .dirt,
    .b = .water,
};

var loaded = false;

pub fn tick(input_data: input.Layout) void {
    if (!loaded) {
        loadMap(.{
        .a = plain.A,
        .b = plain.B,
    }, tile_mapping);
        loaded = true;
    }
    const buttons_lo = input_data.buttons_lo;
    // move around cursor
    cursor.last_move += 1;
    if ((buttons_lo & input.BTN_LEFT) != 0 and cursor.now > 0 and cursor.last_move > 16) {
        cursor.now -= 1;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_RIGHT) != 0 and cursor.now < LENGTH - 1 and cursor.last_move > 16) {
        cursor.now += 1;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_UP) != 0 and cursor.now > WIDTH - 1 and cursor.last_move > 16) {
        cursor.now -= WIDTH;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_DOWN) != 0 and cursor.now < LENGTH - WIDTH and cursor.last_move > 16) {
        cursor.now += WIDTH;
        cursor.last_move = 0;
    }

    // Buttons

    // A
    if ((buttons_lo & input.BTN_A) != 0) {
        setTileRaw(cursor.now, .water);
    }

    // B
    if ((buttons_lo & input.BTN_B) != 0) {
        setTileRaw(cursor.now, .stone);
    }

    // X
    if ((buttons_lo & input.BTN_X) != 0) {
        setTileRaw(cursor.now, .grass);
    }

    // Y
    if ((buttons_lo & input.BTN_Y) != 0) {
        setTileRaw(cursor.now, .dirt);
    }
}

pub fn render() void {
    ui.clearScreen(BG);
    var ty: u32 = 0;
    while (ty < HEIGHT) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < WIDTH) : (tx += 1) {
            const x = tx * TILE_SIZE;
            const y = ty * TILE_SIZE;
            const kind = getTile(tx, ty);
            const color = switch (kind) {
                .wall => colors.C64_DARK_GRAY,
                .dirt => colors.C64_BROWN,
                .stone => colors.C64_PURPLE,
                .water => colors.C64_LIGHT_BLUE,
                .grass => colors.C64_GREEN,
                .empty => colors.C64_BLACK,
            };

            const pattern = switch (kind) {
                .grass => patterns_outside.GRASS,
                .water => patterns_outside.WATER,
                .dirt => patterns_outside.DIRT,
                .stone => patterns_outside.STONE,
                .wall => patterns_outside.WALL,
                .empty => patterns_general.EMPTY,
            };

            renderer.drawBitmap8x8(x, y, pattern, color, colors.C64_BLACK);
            const gridPosition = tileIndex(tx, ty);
            if (gridPosition == cursor.now) {
                renderer.drawRectOutline(x, y, TILE_SIZE, TILE_SIZE, colors.C64_RED);
            }
        }
    }
}
