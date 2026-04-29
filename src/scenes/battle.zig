const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const font = @import("../font.zig");
const ui = @import("../ui.zig");

const grid = @import("../grid.zig");

const patterns_world = @import("../patterns_world.zig");
const patterns_outside = @import("../patterns_outside.zig");
const BTN_ANY_CONFIRM =
    input.BTN_A |
    input.BTN_B |
    input.BTN_X |
    input.BTN_Y;

const BG = colors.C64_BLACK;

/// 2D position.
const Point = struct {
    x: u32,
    y: u32,
};
 
const Cursor = struct { now: u32, former: u32, last_move: u32 };

var cursor = Cursor{ .now = 0, .former = 0, .last_move = 0 };

pub fn tick(input_data: input.Layout) void {
    const buttons_lo = input_data.buttons_lo;
 
 
    cursor.last_move += 1;
 
    if ((buttons_lo & input.BTN_LEFT) != 0 and cursor.now > 0 and cursor.last_move > 16) {
        cursor.now -= 1;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_RIGHT) != 0 and cursor.now < grid.LENGTH - 1 and cursor.last_move > 16) {
        cursor.now += 1;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_UP) != 0 and cursor.now > grid.WIDTH - 1 and cursor.last_move > 16) {
        cursor.now -= grid.WIDTH;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_DOWN) != 0 and cursor.now < grid.LENGTH - grid.WIDTH and cursor.last_move > 16) {
        cursor.now += grid.WIDTH;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_A) != 0) {
   
        grid.setTileRaw(cursor.now, .plains);
    }
    if ((buttons_lo & input.BTN_B) != 0) {
   
        grid.setTileRaw(cursor.now, .mountain);
    }
    if ((buttons_lo & input.BTN_X) != 0) {
      
        grid.setTileRaw(cursor.now, .river);
    }
    if ((buttons_lo & input.BTN_Y) != 0) {
    
        grid.setTileRaw(cursor.now, .forest);
    }
 
 
}

pub fn render() void {
    ui.clearScreen(BG);
    var ty: u32 = 0;
    while (ty < grid.HEIGHT) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < grid.WIDTH) : (tx += 1) {
            const x = tx * grid.TILE_SIZE;
            const y = ty * grid.TILE_SIZE;
            const kind = grid.getTile(tx, ty);
            const color = switch (kind) {
                .wall => colors.C64_DARK_GRAY,
                .dirt => colors.C64_BROWN,
                .stone => colors.C64_PURPLE,
                .water => colors.C64_LIGHT_BLUE,
                .grass => colors.C64_GREEN,
                .plains => colors.C64_LIGHT_GREEN,
                .forest => colors.C64_GREEN,
                .mountain => colors.C64_LIGHT_GRAY,
                .river => colors.C64_BLUE,
            };

            const pattern = switch (kind) {
                .grass => patterns_outside.GRASS,
                .water => patterns_outside.WATER,
                .dirt => patterns_outside.DIRT,
                .stone => patterns_outside.STONE,
                .wall => patterns_outside.WALL,
                .plains => patterns_world.PLAINS,
                .forest => patterns_world.FOREST,
                .mountain => patterns_world.MOUNTAIN,
                .river => patterns_world.RIVER,
            };
            const gridPosition = grid.tileIndex(tx, ty);
            if (gridPosition == cursor.now) {
                renderer.drawRectOutline(x, y, grid.TILE_SIZE, grid.TILE_SIZE, colors.C64_RED);
            } else {
                renderer.drawBitmap8x8(x, y, pattern, color, colors.C64_BLACK);
            }
        }
    }

  
    ui.drawMenuItem(8 * 1, "battle", BG, colors.C64_RED);
}
