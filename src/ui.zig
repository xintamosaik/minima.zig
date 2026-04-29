const renderer = @import("render.zig");
const font = @import("font.zig");

pub fn drawMenuItem(y: u32, label: []const u8, fg: u32, bg: u32) void {
    renderer.fillRect(24, y, 280, 24, bg);
    font.drawString(32, y + 8, label, fg, bg);
}

pub fn clearScreen(color: u32) void {
    renderer.fillRect(0, 0, renderer.WIDTH, renderer.HEIGHT, color);
}
