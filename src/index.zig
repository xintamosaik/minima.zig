extern "env" fn console_log(value: u32) void;

const renderer = @import("render.zig");
const input = @import("input.zig");

const scene = @import("scene.zig");

// Scenes
const intro = @import("scenes/intro.zig");
const menu = @import("scenes/menu.zig");
const new = @import("scenes/new.zig");
const load = @import("scenes/load.zig");
const credits = @import("scenes/credits.zig");
const options = @import("scenes/options.zig");
const battle = @import("scenes/battle.zig");


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

/// Advances simulation by one fixed step.
export fn tick() void {
    switch (scene.scene) {
        .last => battle.tick(input_data),
        .intro => intro.tick(input_data),
        .menu => menu.tick(input_data),
        .credits => credits.tick(input_data),
        .options => options.tick(input_data),
        .new => new.tick(input_data), // or whatever "game" render is
        .load => load.tick(input_data), // placeholder
        .exit => intro.tick(input_data), // placeholder
    }
}

/// Renders the current frame
export fn render() void {
    switch (scene.scene) {
        .last => battle.render(),
        .options => options.render(),
        .intro => intro.render(),
        .menu => menu.render(),
        .credits => credits.render(),
        .new => new.render(), // or whatever "game" render is
        .load => load.render(), // placeholder
        .exit => intro.render(), // placeholder
    }
}

/// Initializes world state.
export fn init() void {
    console_log(0);
    scene.scene = .last;
}
