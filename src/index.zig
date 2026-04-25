extern "env" fn console_log(value: u32) void;

const renderer = @import("render.zig");
const grid = @import("grid.zig");
const input = @import("input.zig");
const colors = @import("colors.zig");

/// Exported for calculations in JS (Width);
export fn width() i32 {
    return renderer.SCREEN_W;
}

/// Exported for calculations in JS (Height);
export fn height() i32 {
    return renderer.SCREEN_H;
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
export var input_data: input.InputData = .{
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
    return @sizeOf(input.InputData);
}

/// Exports byte offsets for mouse fields so JS stays in sync with InputData layout.
export fn inputButtonsLoOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.InputData, "buttons_lo")));
}
export fn inputButtonsHiOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.InputData, "buttons_hi")));
}
export fn inputMouseXOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.InputData, "mouse_x")));
}
export fn inputMouseYOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.InputData, "mouse_y")));
}
export fn inputMouseButtonsOffset() u32 {
    return @as(u32, @intCast(@offsetOf(input.InputData, "mouse_buttons")));
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
    const max_x = renderer.SCREEN_W - player1.w;
    const max_y = renderer.SCREEN_H - player1.h;

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
    if ((buttons_lo & input.BTN_A) != 0) {
        player1.color = colors.C64_CYAN;
    }
    if ((buttons_lo & input.BTN_B) != 0) {
        player1.color = colors.C64_ORANGE;
    }
    if ((buttons_lo & input.BTN_X) != 0) {
        player1.color = colors.C64_GREEN;
    }
    if ((buttons_lo & input.BTN_Y) != 0) {
        player1.color = colors.C64_PURPLE;
    }

    if (mousebuttons > 0) {
        const tx = if (mousex >= renderer.SCREEN_W) (grid.GRID_W - 1) else (mousex / grid.TILE_SIZE);
        const ty = if (mousey >= renderer.SCREEN_H) (grid.GRID_H - 1) else (mousey / grid.TILE_SIZE);

        if ((mousebuttons & input.MOUSE_BUTTON_LEFT) != 0) {
            grid.setTile(tx, ty, .light);
        }
        if ((mousebuttons & input.MOUSE_BUTTON_RIGHT) != 0) {
            grid.setTile(tx, ty, .dark);
        }
        if ((mousebuttons & input.MOUSE_BUTTON_MIDDLE) != 0) {
            grid.setTile(tx, ty, .wall);
        }
    }
    const playerTileX = if (player1.pos.x >= renderer.SCREEN_W) (grid.GRID_W - 1) else (player1.pos.x / grid.TILE_SIZE);
    const playerTileY = if (player1.pos.y >= renderer.SCREEN_H) (grid.GRID_H - 1) else (player1.pos.y / grid.TILE_SIZE);
    const activeGrid = grid.tileIndex(playerTileX, playerTileY);
    grid.setTile(playerTileX, playerTileY, .wall);
    console_log(activeGrid);
}

/// Renders the current frame
export fn render() void {
    var ty: u32 = 0;
    while (ty < grid.GRID_H) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < grid.GRID_W) : (tx += 1) {
            const x = tx * grid.TILE_SIZE;
            const y = ty * grid.TILE_SIZE;
            const kind = grid.getTile(tx, ty);
            const color = switch (kind) {
                .light => colors.C64_LIGHT_GRAY,
                .dark => colors.C64_DARK_GRAY,
                .wall => player1.color,
            };
            renderer.fillRect(x, y, grid.TILE_SIZE, grid.TILE_SIZE, color);
        }
    }

    renderer.drawRectOutline(player1.pos.x, player1.pos.y, player1.w, player1.h, player1.color);
}

/// Initializes world state.
export fn init() void {
    var ty: u32 = 0;
    while (ty < grid.GRID_H) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < grid.GRID_W) : (tx += 1) {
            const use_light = ((tx + ty) & 1) == 0;
            grid.setTile(tx, ty, if (use_light) .light else .dark);
        }
    }
}
