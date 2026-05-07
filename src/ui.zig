const renderer = @import("render.zig");
const font = @import("font.zig");

pub const MENU_MARGIN_LEFT: u32 = 16;
pub const MENU_WIDTH: u32 = 8 * 36;
pub const MENU_HEIGHT: u32 = 24;

pub const MenuItem = struct {
    label: []const u8,
    y: u32,
    color: u32,
};

pub fn drawMenuItem(y: u32, label: []const u8, fg: u32, bg: u32) void {
    renderer.fillRect(MENU_MARGIN_LEFT, y, MENU_WIDTH, MENU_HEIGHT, bg);
    font.drawString(24, y + 8, label, fg, bg);
}

pub fn clearScreen(color: u32) void {
    renderer.fillRect(0, 0, renderer.WIDTH, renderer.HEIGHT, color);
}

pub fn u999ToChars(n: u32) [3]u8 {
    var value = n;
    if (value > 999) value = 999;

    return .{
        @as(u8, @intCast('0' + (value / 100) % 10)),
        @as(u8, @intCast('0' + (value / 10) % 10)),
        @as(u8, @intCast('0' + value % 10)),
    };
}
