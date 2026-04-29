const renderer = @import("render.zig");
const font = @import("font.zig");

pub fn drawMenuItem(y: u32, label: []const u8, fg: u32, bg: u32) void {
    renderer.fillRect(24, y, 280, 24, bg);
    font.drawString(32, y + 8, label, fg, bg);
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
