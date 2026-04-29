const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const font = @import("../font.zig");

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
    font.drawString(24, 8 * 1, "                                  ", colors.C64_BLACK, colors.C64_CYAN);
    font.drawString(24, 8 * 2, " minima                           ", colors.C64_BLACK, colors.C64_CYAN);
    font.drawString(24, 8 * 3, "                                  ", colors.C64_BLACK, colors.C64_CYAN);
    font.drawString(24, 8 * 4, " a retro game written in zig/wasm ", colors.C64_BLACK, colors.C64_CYAN);
    font.drawString(24, 8 * 5, "                                  ", colors.C64_BLACK, colors.C64_CYAN);

    font.drawString(24, 8 * 10, "                                  ", colors.C64_BLACK, colors.C64_YELLOW);
    font.drawString(24, 8 * 11, " Press any key                    ", colors.C64_BLACK, colors.C64_YELLOW);
    font.drawString(24, 8 * 12, "                                  ", colors.C64_BLACK, colors.C64_YELLOW);
    font.drawString(24, 8 * 13, " to continue                      ", colors.C64_BLACK, colors.C64_YELLOW);
    font.drawString(24, 8 * 14, "                                  ", colors.C64_BLACK, colors.C64_YELLOW);
}
