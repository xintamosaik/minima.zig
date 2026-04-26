const grid = @import("grid.zig");

/// 128 = 8 * 16. 128 is somewhat close to retro resolutions
pub const WIDTH: u32 = grid.WIDTH * grid.TILE_SIZE;
/// 96 = 8 * 12. 96 is somewhat close to retro resolutions
pub const HEIGHT: u32 = grid.HEIGHT * grid.TILE_SIZE;

/// Raw pixel count of the frame buffer.
const PIXELS = WIDTH * HEIGHT;
/// Zig allocates this in module memory; JS can query its base via `framePtr()`.
pub var frame_buffer: [PIXELS]u32 = undefined;

/// Writes one 32-bit pixel into the frame buffer.
fn writePixel32(x: u32, y: u32, color: u32) void {
    if (x >= WIDTH or y >= HEIGHT) return;
    const index = @as(usize, @intCast(y * WIDTH + x));
    frame_buffer[index] = color;
}

/// Fills a clipped rectangle.
pub fn fillRect(x: u32, y: u32, w: u32, h: u32, color: u32) void {
    const x0 = x;
    const y0 = y;
    var x1 = x +| w;
    var y1 = y +| h;

    if (x1 > WIDTH) x1 = WIDTH;
    if (y1 > HEIGHT) y1 = HEIGHT;

    if (x0 >= x1 or y0 >= y1) return;

    var py = y0;
    while (py < y1) : (py += 1) {
        const row_start = @as(usize, @intCast(py * WIDTH));
        var px = x0;
        while (px < x1) : (px += 1) {
            frame_buffer[row_start + @as(usize, @intCast(px))] = color;
        }
    }
}

/// Draws a clipped horizontal line.
fn drawHorizontalLine(x0: u32, x1: u32, y: u32, color: u32) void {
    if (y >= HEIGHT) return;
    if (x1 <= x0) return;

    const cx0 = if (x0 > WIDTH) WIDTH else x0;
    const cx1 = if (x1 > WIDTH) WIDTH else x1;
    if (cx1 <= cx0) return;

    var px = cx0;
    while (px < cx1) : (px += 1) {
        writePixel32(px, y, color);
    }
}

/// Draws a clipped vertical line.
fn drawVerticalLine(x: u32, y0: u32, y1: u32, color: u32) void {
    if (x >= WIDTH) return;
    if (y1 <= y0) return;

    const cy0 = if (y0 > HEIGHT) HEIGHT else y0;
    const cy1 = if (y1 > HEIGHT) HEIGHT else y1;
    if (cy1 <= cy0) return;

    var py = cy0;
    while (py < cy1) : (py += 1) {
        writePixel32(x, py, color);
    }
}
/// Draws a rectangle outline.
pub fn drawRectOutline(x: u32, y: u32, w: u32, h: u32, color: u32) void {
    if (w == 0 or h == 0) return;

    const x1 = x +| w;
    const y1 = y +| h;
    const xr = x +| (w - 1);
    const yb = y +| (h - 1);

    drawHorizontalLine(x, x1, y, color);
    drawHorizontalLine(x, x1, yb, color);
    drawVerticalLine(x, y, y1, color);
    drawVerticalLine(xr, y, y1, color);
}
