const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const ui = @import("ui.zig");

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
    renderer.fillRect(0, 0, renderer.WIDTH, renderer.HEIGHT, colors.C64_BLACK);
    ui.drawMenuItem(8 * 1, "credits", colors.C64_BLACK, colors.C64_ORANGE);
}
