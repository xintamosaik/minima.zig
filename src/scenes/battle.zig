const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const font = @import("../font.zig");
const ui = @import("../ui.zig");
const maps = @import("../maps/maps.zig");
const grid = @import("../grid.zig"); 
const patterns_outside = @import("../patterns_outside.zig");
const patterns_general = @import("../patterns_general.zig");
const plain = @import("../maps/battle/plain.zig");

const TILE_SIZE: u32 = 8;
const WIDTH: u32 = 40;
const HEIGHT: u32 = 25;
const LENGTH = WIDTH * HEIGHT;


/// Initial map data; `init()` overwrites this with a checkerboard.
var world_tiles: [LENGTH]grid.TileKind = [_]grid.TileKind{.empty} ** LENGTH;

const BG = colors.C64_BLACK;

const Cursor = struct { now: u32, former: u32, last_move: u32 };

var cursor = Cursor{ .now = 0, .former = 0, .last_move = 0 };





const tile_mapping = maps.TileMapping{
    .base = .empty,
    .a = .dirt,
    .b = .water,
};

var loaded = false;

pub fn tick(input_data: input.Layout) void {
    if (!loaded) {
        maps.loadMap(.{
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
       
    }

    // B
    if ((buttons_lo & input.BTN_B) != 0) {}

    // X
    if ((buttons_lo & input.BTN_X) != 0) {}

    // Y
    if ((buttons_lo & input.BTN_Y) != 0) {}
}

pub fn render() void {
    ui.clearScreen(BG);
    var ty: u32 = 0;
    while (ty < HEIGHT) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < WIDTH) : (tx += 1) {
            const x = tx * TILE_SIZE;
            const y = ty * TILE_SIZE;
            const kind = grid.getTile(tx, ty);
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
            const gridPosition = grid.tileIndex(tx, ty);
            if (gridPosition == cursor.now) {
                renderer.drawRectOutline(x, y, TILE_SIZE, TILE_SIZE, colors.C64_RED);
            }
        }
    }
    font.drawString(0, 24*8, "BARBARIAN", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(32*8, 0, "HP: 120", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(32*8, 8, "AP:   9", colors.C64_CYAN, colors.C64_BLACK);
    
}
