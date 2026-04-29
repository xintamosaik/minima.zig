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
    ui.drawMenuItem(8 * 1, "options", BG, colors.C64_PURPLE);
}
