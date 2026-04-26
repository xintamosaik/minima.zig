extern "env" fn console_log(value: u32) void;

const renderer = @import("render.zig");
const grid = @import("grid.zig");
const input = @import("input.zig");
const font = @import("font.zig");
const colors = @import("colors.zig");

const patterns_world = @import("patterns_world.zig");
const patterns_outside = @import("patterns_outside.zig");

/// Exported for calculations in JS (Width);
export fn width() i32 {
    return renderer.WIDTH;
}

/// Exported for calculations in JS (Height);
export fn height() i32 {
    return renderer.HEIGHT;
}

/// Exports the byte offset of the frame buffer for JS to write pixel data into.
export fn framePtr() u32 {
    return @as(u32, @intCast(@intFromPtr(&renderer.frame_buffer[0])));
}
/// Exports the byte length of the frame buffer for JS memory management.
export fn frameLen() u32 {
    return @sizeOf(@TypeOf(renderer.frame_buffer));
}

/// C-layout input block keeps byte offsets stable for JS DataView writes.
/// JS writes input state into this struct each frame, and Zig reads from it in `tick()`.
export var input_data: input.Layout = .{
    .buttons_lo = 0,
    .buttons_hi = 0,
    ._reserved = 0,
    .mouse_x = 0,
    .mouse_y = 0,
    .mouse_buttons = 0,
};

/// Exports the byte offset of the input data block for JS to write input state into.
export fn inputPtr() u32 {
    return @as(u32, @intCast(@intFromPtr(&input_data)));
}
/// Exports the byte length of the input data block for JS memory management.
export fn inputLen() u32 {
    return @sizeOf(input.Layout);
}

/// Exports byte offsets for mouse fields so JS stays in sync with InputData layout.
export fn inputButtonsLoOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.Layout, "buttons_lo")));
}
export fn inputButtonsHiOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.Layout, "buttons_hi")));
}
export fn inputMouseXOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.Layout, "mouse_x")));
}
export fn inputMouseYOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.Layout, "mouse_y")));
}
export fn inputMouseButtonsOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.Layout, "mouse_buttons")));
}

/// Host-owned pointer fields written by JS each frame.
/// Mouse coordinate (x)
export fn mouse_x() u32 {
    return input_data.mouse_x;
}

/// Mouse coordinate (y)
export fn mouse_y() u32 {
    return input_data.mouse_y;
}

/// Mouse button state as a bitmask (left=1, middle=2, right=4).
export fn mouse_buttons() u32 {
    return input_data.mouse_buttons;
}

/// 2D position.
const Point = struct {
    x: u32,
    y: u32,
};
const Cursor = struct { now: u32, former: u32, last_move: u32 };

var cursor = Cursor{ .now = 0, .former = 0, .last_move = 0 };
/// Minimal player state.
const Player = struct {
    pos: Point,
    color: u32,
    h: u32 = 2,
    w: u32 = 2,
};

/// Single active player.
var player1 = Player{
    .pos = Point{ .x = 60, .y = 40 },
    .color = colors.C64_BLUE,
};

/// Advances simulation by one fixed step.
export fn tick() void {
    const buttons_lo = input_data.buttons_lo;
    const mousex = input_data.mouse_x;
    const mousey = input_data.mouse_y;
    const mousebuttons = input_data.mouse_buttons;
    const max_x = renderer.WIDTH - player1.w;
    const max_y = renderer.HEIGHT - player1.h;
    cursor.last_move += 1;
    if ((buttons_lo & input.BTN_LEFT) != 0 and player1.pos.x > 0) {
        player1.pos.x -= 1;
    }
    if ((buttons_lo & input.BTN_RIGHT) != 0 and player1.pos.x < max_x) {
        player1.pos.x += 1;
    }
    if ((buttons_lo & input.BTN_UP) != 0 and player1.pos.y > 0) {
        player1.pos.y -= 1;
    }
    if ((buttons_lo & input.BTN_DOWN) != 0 and player1.pos.y < max_y) {
        player1.pos.y += 1;
    }
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
        player1.color = colors.C64_CYAN;
        grid.setTileRaw(cursor.now, .plains);
    }
    if ((buttons_lo & input.BTN_B) != 0) {
        player1.color = colors.C64_ORANGE;
        grid.setTileRaw(cursor.now, .mountain);
    }
    if ((buttons_lo & input.BTN_X) != 0) {
        player1.color = colors.C64_GREEN;
        grid.setTileRaw(cursor.now, .river);
    }
    if ((buttons_lo & input.BTN_Y) != 0) {
        player1.color = colors.C64_PURPLE;
        grid.setTileRaw(cursor.now, .forest);
    }
    if (mousebuttons > 0) {
        const tx = if (mousex >= renderer.WIDTH) (grid.WIDTH - 1) else (mousex / grid.TILE_SIZE);
        const ty = if (mousey >= renderer.HEIGHT) (grid.HEIGHT - 1) else (mousey / grid.TILE_SIZE);

        if ((mousebuttons & input.MOUSE_BUTTON_LEFT) != 0) {
            grid.setTile(tx, ty, .dirt);
        }
        if ((mousebuttons & input.MOUSE_BUTTON_RIGHT) != 0) {
            grid.setTile(tx, ty, .stone);
        }
        if ((mousebuttons & input.MOUSE_BUTTON_MIDDLE) != 0) {
            grid.setTile(tx, ty, .wall);
        }
    }
    const playerTileX = if (player1.pos.x >= renderer.WIDTH) (grid.WIDTH - 1) else (player1.pos.x / grid.TILE_SIZE);
    const playerTileY = if (player1.pos.y >= renderer.HEIGHT) (grid.HEIGHT - 1) else (player1.pos.y / grid.TILE_SIZE);

    grid.setTile(playerTileX, playerTileY, .stone);
}

/// Renders the current frame
export fn render() void {
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
                .river => colors.C64_BLUE
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
                .river => patterns_world.RIVER
            };
            const gridPosition = grid.tileIndex(tx, ty);
            if (gridPosition == cursor.now) {
                renderer.drawRectOutline(x, y, grid.TILE_SIZE, grid.TILE_SIZE, colors.C64_RED);
            } else {
                renderer.drawBitmap8x8(x, y, pattern, color, colors.C64_BLACK);
            }
        }
    }

    renderer.drawRectOutline(player1.pos.x, player1.pos.y, player1.w, player1.h, player1.color);
    font.drawString(16, 16, "minima", colors.C64_BLACK, colors.C64_CYAN);
    font.drawString(16, 32, "a retro game written in zig/wasm", colors.C64_BLACK, colors.C64_CYAN);
}

/// Initializes world state.
export fn init() void {
    console_log(0);
}
