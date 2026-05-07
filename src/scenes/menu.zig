const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const ui = @import("../ui.zig");

const WAIT = 16;
const MenuItem = struct {
    label: []const u8,
    y: u32,
    color: u32,
    action: scene.Scene,
};
const items = [_]MenuItem{
    .{ .label = "continue", .y = 8 * 1, .color = colors.C64_YELLOW, .action = .battle_plain_goblins },
    .{ .label = "load", .y = 8 * 5, .color = colors.C64_BLUE, .action = .load },
    .{ .label = "new", .y = 8 * 9, .color = colors.C64_GREEN, .action = .new },
    .{ .label = "credits", .y = 8 * 13, .color = colors.C64_ORANGE, .action = .credits },
    .{ .label = "options", .y = 8 * 17, .color = colors.C64_PURPLE, .action = .options },
    .{ .label = "exit", .y = 8 * 21, .color = colors.C64_RED, .action = .exit },
};

var selected: usize = 0;
var movedLast: u32 = 0;
const LAST_ITEM: usize = items.len - 1;
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
        scene.request(items[selected].action);
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
        ui.MENU_MARGIN_LEFT,
        item.y,
        ui.MENU_WIDTH,
        ui.MENU_HEIGHT,
        colors.C64_WHITE,
    );
}
