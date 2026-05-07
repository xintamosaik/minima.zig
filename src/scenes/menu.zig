const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const ui = @import("../ui.zig");

const WAIT = 16;

const items = [_]ui.MenuItem{
    .{ .label = "continue", .target = .battle_plain_goblins, .y = 8 * 1, .color = colors.C64_YELLOW },
    .{ .label = "load", .target = .load, .y = 8 * 5, .color = colors.C64_BLUE },
    .{ .label = "new", .target = .new, .y = 8 * 9, .color = colors.C64_GREEN },
    .{ .label = "credits", .target = .credits, .y = 8 * 13, .color = colors.C64_ORANGE },
    .{ .label = "options", .target = .options, .y = 8 * 17, .color = colors.C64_PURPLE },
    .{ .label = "exit", .target = .exit, .y = 8 * 21, .color = colors.C64_RED },
};

var selected: usize = 0;
var movedLast: u32 = 0;
const LAST_ITEM: u32 = @intCast(items.len - 1);
pub fn tick(input_data: input.Layout) void {
    const buttons_lo = input_data.buttons_lo;
    const buttons_hi = input_data.buttons_hi;

    movedLast += 1;

    if ((buttons_lo & input.BTN_UP) != 0 and selected > 0 and movedLast > WAIT) {
        selected -= 1;
        movedLast = 0;
    }

    if ((buttons_lo & input.BTN_DOWN) != 0 and selected < LAST_ITEM and movedLast > WAIT) {
        selected += 1;
        movedLast = 0;
    }

    if ((buttons_hi & input.BTN_START) != 0) {
        scene.request(items[selected].target);
    }
}

pub fn render() void {
    const BG = colors.C64_BLACK;

    ui.clearScreen(BG);

    for (items) |item| {
        ui.drawMenuItem(item.y, item.label, BG, item.color);
    }

    const item = items[selected];

    renderer.drawRectOutline(
        item.x,
        item.y,
        item.w,
        item.h,
        colors.C64_WHITE,
    );
}
