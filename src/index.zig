extern "env" fn console_log(value: i32) void;
const MEMORY_BASE_PTR: u32 = 1024;

const SCREEN_W: i32 = 128;
const SCREEN_H: i32 = 96;

const BPP: u32 = 4;

const FRAME_LEN: u32 = @as(u32, SCREEN_W) * @as(u32, SCREEN_H) * BPP;
const FRAME_PTR: u32 = MEMORY_BASE_PTR;
const FRAME_END: u32 = FRAME_PTR + FRAME_LEN;

const INPUT_LEN: u32 = 16;
const INPUT_PTR: u32 = FRAME_END;
const INPUT_END: u32 = INPUT_PTR + INPUT_LEN;
export fn tick() void {
    console_log(42);
}

export fn width() i32 {
    return SCREEN_W;
}

export fn height() i32 {
    return SCREEN_H;
}

export fn framePtr() u32 {
    return FRAME_PTR;
}

export fn frameLen() u32 {
    return FRAME_LEN;
}

export fn inputPtr() u32 {
    return INPUT_PTR;
}

export fn inputLen() u32 {
    return INPUT_LEN;
}

/// Packs RGBA channels into one 32-bit pixel.
fn rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    return @as(u32, r)
        | (@as(u32, g) << 8)
        | (@as(u32, b) << 16)
        | (@as(u32, a) << 24);
}

/// Writes one 32-bit pixel into linear memory at byte offset `offset`.
fn writePixel32(offset: u32, color: u32) void {
    const ptr: *u32 = @ptrFromInt(offset);
    ptr.* = color;
}

const BG_TILE: i32 = 8;
fn fillRect(x: i32, y: i32, w: i32, h: i32, color: u32) void {
    var x0 = x;
    var y0 = y;
    var x1 = x + w;
    var y1 = y + h;

    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > SCREEN_W) x1 = SCREEN_W;
    if (y1 > SCREEN_H) y1 = SCREEN_H;

    if (x0 >= x1 or y0 >= y1) return;

    var py = y0;
    while (py < y1) : (py += 1) {
        var px = x0;
        var row: u32 = FRAME_PTR + @intCast((py * SCREEN_W + x0)) * BPP;

        while (px < x1) : (px += 1) {
            writePixel32(row, color);
            row += 4;
        }
    }
}
const C_BG_A: u32 = rgba(40, 24, 28, 255);
const C_BG_B: u32 = rgba(46, 30, 34, 255);
fn drawCheckerboardBackground() void {
    var y: i32 = 0;
    while (y < SCREEN_H) : (y += BG_TILE) {
        var x: i32 = 0;
        while (x < SCREEN_W) : (x += BG_TILE) {
            const tx = @divTrunc(x, BG_TILE);
            const ty = @divTrunc(y, BG_TILE);
            const use_a = ((tx + ty) & 1) == 0;

            fillRect(x, y, BG_TILE, BG_TILE, if (use_a) C_BG_A else C_BG_B);
        }
    }
}