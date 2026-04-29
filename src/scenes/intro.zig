const input = @import("../input.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const ui = @import("../ui.zig");

const BTN_ANY_CONFIRM =
    input.BTN_A |
    input.BTN_B |
    input.BTN_X |
    input.BTN_Y;

pub fn tick(input_data: input.Layout) void {
    if ((input_data.buttons_lo & BTN_ANY_CONFIRM) != 0 or (input_data.mouse_buttons & input.MOUSE_BUTTON_LEFT) != 0) {
        scene.scene = .menu;
    }
}

pub fn render() void {
    const BG = colors.C64_BLACK;
    ui.clearScreen(BG);

    ui.drawMenuItem(8 * 1, "minima", BG, colors.C64_CYAN);
    ui.drawMenuItem(8 * 3, "a retro game written in zig/wasm", BG, colors.C64_CYAN);

    ui.drawMenuItem(8 * 10, "Press any key", BG, colors.C64_YELLOW);
    ui.drawMenuItem(8 * 12, "to continue", BG, colors.C64_YELLOW);
}
