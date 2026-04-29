const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const ui = @import("../ui.zig");

const Cursor2DRaw = struct {
    movedLast: u32,
    x: u32,
    y: u32,
    color: u32,
    h: u32 = 24,
    w: u32 = 24,
};

const WAIT = 16;

var menuCursor = Cursor2DRaw{ .movedLast = 0, .x = 24, .y = 8, .color = colors.C64_BLUE, .w = 8 * 35, .h = 24 };

pub fn tick(input_data: input.Layout) void {
    const buttons_lo = input_data.buttons_lo;
    const buttons_hi = input_data.buttons_hi;
    const JUMP = 32;
    const MENU_MIN = 8 + JUMP;
    const MENU_MAX = 8 * 20;
    menuCursor.movedLast += 1;

    if ((buttons_lo & input.BTN_UP) != 0 and menuCursor.y >= MENU_MIN and menuCursor.movedLast > WAIT) {
        menuCursor.movedLast = 0;
        menuCursor.y -= JUMP;
    }
    if ((buttons_lo & input.BTN_DOWN) != 0 and menuCursor.y <= MENU_MAX and menuCursor.movedLast > WAIT) {
        menuCursor.movedLast = 0;
        menuCursor.y += JUMP;
    }

    if ((buttons_hi & input.BTN_START) != 0) {
        if (menuCursor.y == 8 + (JUMP * 0)) {
            scene.scene = .last;
        } else if (menuCursor.y == 8 + (JUMP * 1)) {
            scene.scene = .load;
        } else if (menuCursor.y == 8 + (JUMP * 2)) {
            scene.scene = .new;
        } else if (menuCursor.y == 8 + (JUMP * 3)) {
            scene.scene = .credits;
        } else if (menuCursor.y == 8 + (JUMP * 4)) {
            scene.scene = .options;
        } else if (menuCursor.y == 8 + (JUMP * 5)) {
            scene.scene = .exit;
        }
    }
}

pub fn render() void {
      const BG = colors.C64_BLACK;

    ui.clearScreen(BG);

    ui.drawMenuItem(8 * 1, "continue", BG, colors.C64_YELLOW);
    ui.drawMenuItem(8 * 5, "load", BG, colors.C64_BLUE);
    ui.drawMenuItem(8 * 9, "new", BG, colors.C64_GREEN);
    ui.drawMenuItem(8 * 13, "credits", BG, colors.C64_ORANGE);
    ui.drawMenuItem(8 * 17, "options", BG, colors.C64_PURPLE);
    ui.drawMenuItem(8 * 21, "exit", BG, colors.C64_RED);
    
    renderer.drawRectOutline(menuCursor.x, menuCursor.y, menuCursor.w, menuCursor.h, colors.C64_WHITE);
}
