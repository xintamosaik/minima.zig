extern "env" fn console_log(value: u32) void;

const MEMORY_BASE_PTR: u32 = 1024;

const SCREEN_W: u32 = 128;
const SCREEN_H: u32 = 96;
const TILE_SIZE: u32 = 8;
const GRID_W: usize = @as(usize, SCREEN_W / TILE_SIZE);
const GRID_H: usize = @as(usize, SCREEN_H / TILE_SIZE);
const GRID_W_U32: u32 = @as(u32, @intCast(GRID_W));
const GRID_H_U32: u32 = @as(u32, @intCast(GRID_H));

const BPP: u32 = 4;

const FRAME_PTR: u32 = MEMORY_BASE_PTR;
const FRAME_LEN: u32 = SCREEN_W * SCREEN_H * BPP;
const FRAME_END: u32 = FRAME_PTR + FRAME_LEN;

const INPUT_PTR: u32 = FRAME_END;
const INPUT_KEY_BYTES: u32 = 8;
const MOUSE_X_PTR: u32 = INPUT_PTR + INPUT_KEY_BYTES;
const MOUSE_Y_PTR: u32 = MOUSE_X_PTR + 4;
const MOUSE_BUTTONS_PTR: u32 = MOUSE_Y_PTR + 4;
const INPUT_LEN: u32 = INPUT_KEY_BYTES + 12;
const INPUT_END: u32 = INPUT_PTR + INPUT_LEN;
const MOUSE_BUTTONS_LEFT: u32 = 1;
const MOUSE_BUTTONS_RIGHT: u32 = 2;

export fn width() i32 { return SCREEN_W; }
export fn height() i32 { return SCREEN_H; }
export fn framePtr() u32 { return FRAME_PTR; }
export fn frameLen() u32 { return FRAME_LEN; }
export fn inputPtr() u32 { return INPUT_PTR; }
export fn inputLen() u32 { return INPUT_LEN; }
export fn mouse_x() u32 { return @as(*const u32, @ptrFromInt(MOUSE_X_PTR)).*; }
export fn mouse_y() u32 { return @as(*const u32, @ptrFromInt(MOUSE_Y_PTR)).*; }
export fn mouse_buttons() u32 { return @as(*const u32, @ptrFromInt(MOUSE_BUTTONS_PTR)).*; }

const Point = struct {
    x: u32,
    y: u32,
};

const Rect: type = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

const Player: type = struct {
    pos: Point,
    color: u32,
    h: u32 = 8,
    w: u32 = 8,
};

var player1: Player = Player{
    .pos = Point{ .x = 60, .y = 40 },
    .color = C64_BLUE,
};

const TileKind = enum(u8) {
    light,
    dark,
    wall,
};

var world_tiles: [GRID_W * GRID_H]TileKind = undefined;

const Input = enum(u32) {
    up = 0,
    down = 1,
    left = 2,
    right = 3,
    confirm = 4,
    cancel = 5,
    reset = 6,
};
fn inputByte(key: Input) u8 {
    return @as(*const u8, @ptrFromInt(INPUT_PTR + @intFromEnum(key))).*;
}
fn inputPressed(key: Input) bool {
    return inputByte(key) != 0;
}

export fn tick() void {
    //^const up = inputPressed(.up);
    //^const down = inputPressed(.down);
    //^const left = inputPressed(.left);
    //^const right = inputPressed(.right);
    //^const confirm = inputPressed(.confirm);
    //^const cancel = inputPressed(.cancel);
    //^const reset = inputPressed(.reset);
    const mousex = @as(*const u32, @ptrFromInt(MOUSE_X_PTR)).*;
    const mousey = @as(*const u32, @ptrFromInt(MOUSE_Y_PTR)).*;
    const mousebuttons = @as(*const u32, @ptrFromInt(MOUSE_BUTTONS_PTR)).*;
    // console_log(mousebuttons);
    // only on mouse clicked:
    if (mousebuttons > 0) {
        const tx = if (mousex >= SCREEN_W) (GRID_W_U32 - 1) else (mousex / TILE_SIZE);
        const ty = if (mousey >= SCREEN_H) (GRID_H_U32 - 1) else (mousey / TILE_SIZE);

        console_log(tx);
        console_log(ty);
        console_log(mousebuttons);
        //console_log(@intFromBool(up));
        //console_log(@intFromBool(down));
        //console_log(@intFromBool(left));
        //console_log(@intFromBool(right));
        //console_log(@intFromBool(confirm));
        //console_log(@intFromBool(cancel));
        //console_log(@intFromBool(reset));
        if ((mousebuttons & MOUSE_BUTTONS_LEFT) != 0) {
            setTile(tx, ty, .wall);
        }
        if ((mousebuttons & MOUSE_BUTTONS_RIGHT) != 0) {
            setTile(tx, ty, .light);
        }

        player1.pos.x = tx * TILE_SIZE;
        player1.pos.y = ty * TILE_SIZE;
    }
}

/// Packs RGBA channels into one 32-bit pixel.
fn rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    return @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16) | (@as(u32, a) << 24);
}

/// Writes one 32-bit pixel into linear memory at byte offset `offset`.
fn writePixel32(offset: u32, color: u32) void {
    const ptr: *u32 = @ptrFromInt(offset);
    ptr.* = color;
}

fn fillRect(x: u32, y: u32, w: u32, h: u32, color: u32) void {
    const x0 = x;
    const y0 = y;
    var x1 = x + w;
    var y1 = y + h;

    if (x1 > SCREEN_W) x1 = SCREEN_W;
    if (y1 > SCREEN_H) y1 = SCREEN_H;

    if (x0 >= x1 or y0 >= y1) return;

    var py = y0;
    while (py < y1) : (py += 1) {
        var px = x0;
        var row: u32 = FRAME_PTR + @as(u32, @intCast(py * SCREEN_W + x0)) * BPP;

        while (px < x1) : (px += 1) {
            writePixel32(row, color);
            row += 4;
        }
    }
}
fn drawHorizontalLine(x0: u32, x1: u32, y: u32, color: u32) void {
    if (y >= SCREEN_H) return;
    if (x1 <= x0) return;

    const cx0 = if (x0 > SCREEN_W) SCREEN_W else x0;
    const cx1 = if (x1 > SCREEN_W) SCREEN_W else x1;
    if (cx1 <= cx0) return;

    var px = cx0;
    var row: u32 = FRAME_PTR + @as(u32, @intCast(y * SCREEN_W + cx0)) * BPP;
    while (px < cx1) : (px += 1) {
        writePixel32(row, color);
        row += BPP;
    }
}

fn drawVerticalLine(x: u32, y0: u32, y1: u32, color: u32) void {
    if (x >= SCREEN_W) return;
    if (y1 <= y0) return;

    const cy0 = if (y0 > SCREEN_H) SCREEN_H else y0;
    const cy1 = if (y1 > SCREEN_H) SCREEN_H else y1;
    if (cy1 <= cy0) return;

    var py = cy0;
    var row: u32 = FRAME_PTR + @as(u32, @intCast(cy0 * SCREEN_W + x)) * BPP;
    while (py < cy1) : (py += 1) {
        writePixel32(row, color);
        row += SCREEN_W * BPP;
    }
}

fn drawRectOutline(x: u32, y: u32, w: u32, h: u32, color: u32) void {
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
// Commodore 64 palette (Pepto-inspired RGB values)
const C64_BLACK: u32 = rgba(0x00, 0x00, 0x00, 0xFF);
const C64_WHITE: u32 = rgba(0xFF, 0xFF, 0xFF, 0xFF);
const C64_RED: u32 = rgba(0x68, 0x37, 0x2B, 0xFF);
const C64_CYAN: u32 = rgba(0x70, 0xA4, 0xB2, 0xFF);
const C64_PURPLE: u32 = rgba(0x6F, 0x3D, 0x86, 0xFF);
const C64_GREEN: u32 = rgba(0x58, 0x8D, 0x43, 0xFF);
const C64_BLUE: u32 = rgba(0x35, 0x28, 0x79, 0xFF);
const C64_YELLOW: u32 = rgba(0xB8, 0xC7, 0x6F, 0xFF);
const C64_ORANGE: u32 = rgba(0x6F, 0x4F, 0x25, 0xFF);
const C64_BROWN: u32 = rgba(0x43, 0x39, 0x00, 0xFF);
const C64_LIGHT_RED: u32 = rgba(0x9A, 0x67, 0x59, 0xFF);
const C64_DARK_GRAY: u32 = rgba(0x44, 0x44, 0x44, 0xFF);
const C64_GRAY: u32 = rgba(0x6C, 0x6C, 0x6C, 0xFF);
const C64_LIGHT_GREEN: u32 = rgba(0x9A, 0xD2, 0x84, 0xFF);
const C64_LIGHT_BLUE: u32 = rgba(0x6C, 0x5E, 0xB5, 0xFF);
const C64_LIGHT_GRAY: u32 = rgba(0x95, 0x95, 0x95, 0xFF);

fn tileIndex(tx: u32, ty: u32) usize {
    return @as(usize, @intCast(ty * GRID_W_U32 + tx));
}

fn setTile(tx: u32, ty: u32, kind: TileKind) void {
    if (tx >= GRID_W_U32 or ty >= GRID_H_U32) return;
    world_tiles[tileIndex(tx, ty)] = kind;
}
export fn render() void {
    // For this example, the background is static and drawn once in `init()`.
    // In a real game, you would likely want to redraw the background each frame
    // or have more complex rendering logic here.
    var ty: u32 = 0;
    while (ty < GRID_H_U32) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < GRID_W_U32) : (tx += 1) {
            const x = tx * TILE_SIZE;
            const y = ty * TILE_SIZE;
            const kind = world_tiles[tileIndex(tx, ty)];
            const color = switch (kind) {
                .light => C64_LIGHT_GRAY,
                .dark => C64_DARK_GRAY,
                .wall => C64_BROWN,
            };
            fillRect(x, y, TILE_SIZE, TILE_SIZE, color);
        }
    }

    // Entity render pass.
    drawRectOutline(player1.pos.x, player1.pos.y, player1.w, player1.h, player1.color);
}
export fn init() void {
    var ty: u32 = 0;
    while (ty < GRID_H_U32) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < GRID_W_U32) : (tx += 1) {
            const use_light = ((tx + ty) & 1) == 0;
            setTile(tx, ty, if (use_light) .light else .dark);
        }
    }
}
