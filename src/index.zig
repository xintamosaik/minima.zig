extern "env" fn console_log(value: u32) void;

const SCREEN_W: u32 = 128;
const SCREEN_H: u32 = 96;
const TILE_SIZE: u32 = 8;
const GRID_W: u32 = SCREEN_W / TILE_SIZE;
const GRID_H: u32 = SCREEN_H / TILE_SIZE;
const GRID_LEN: usize = @as(usize, GRID_W * GRID_H);
const FRAME_PIXELS: usize = @as(usize, SCREEN_W * SCREEN_H);

const BPP: u32 = 4;

const INPUT_KEY_COUNT: usize = 8;

// Zig allocates this in module memory; JS can query its base via `framePtr()`.
export var frame_buffer: [FRAME_PIXELS]u32 = undefined;

const InputData = extern struct {
    keys: [INPUT_KEY_COUNT]u8,
    mouse_x: u32,
    mouse_y: u32,
    mouse_buttons: u32,
};

// C-layout input block keeps byte offsets stable for JS DataView writes.
export var input_data: InputData = .{
    .keys = [_]u8{0} ** INPUT_KEY_COUNT,
    .mouse_x = 0,
    .mouse_y = 0,
    .mouse_buttons = 0,
};

const MOUSE_BUTTONS_LEFT: u32 = 1;
const MOUSE_BUTTONS_RIGHT: u32 = 3;

export fn width() i32 { return SCREEN_W; }
export fn height() i32 { return SCREEN_H; }
export fn framePtr() u32 { return @as(u32, @intCast(@intFromPtr(&frame_buffer[0]))); }
export fn frameLen() u32 { return @sizeOf(@TypeOf(frame_buffer)); }
export fn inputPtr() u32 { return @as(u32, @intCast(@intFromPtr(&input_data))); }
export fn inputLen() u32 { return @sizeOf(InputData); }
export fn mouse_x() u32 { return input_data.mouse_x; }
export fn mouse_y() u32 { return input_data.mouse_y; }
export fn mouse_buttons() u32 { return input_data.mouse_buttons; }

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

var world_tiles: [GRID_LEN]TileKind = undefined;

export fn tick() void {
    const mousex = input_data.mouse_x;
    const mousey = input_data.mouse_y;
    const mousebuttons = input_data.mouse_buttons;

    if (mousebuttons > 0) {
        const tx = if (mousex >= SCREEN_W) (GRID_W - 1) else (mousex / TILE_SIZE);
        const ty = if (mousey >= SCREEN_H) (GRID_H - 1) else (mousey / TILE_SIZE);

        if (mousebuttons == MOUSE_BUTTONS_LEFT) {
            setTile(tx, ty, .wall);
        }
        if (mousebuttons == MOUSE_BUTTONS_RIGHT) {
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

/// Writes one 32-bit pixel into the frame buffer.
fn writePixel32(x: u32, y: u32, color: u32) void {
    if (x >= SCREEN_W or y >= SCREEN_H) return;
    const index = @as(usize, @intCast(y * SCREEN_W + x));
    frame_buffer[index] = color;
}

fn fillRect(x: u32, y: u32, w: u32, h: u32, color: u32) void {
    const x0 = x;
    const y0 = y;
    var x1 = x +| w;
    var y1 = y +| h;

    if (x1 > SCREEN_W) x1 = SCREEN_W;
    if (y1 > SCREEN_H) y1 = SCREEN_H;

    if (x0 >= x1 or y0 >= y1) return;

    var py = y0;
    while (py < y1) : (py += 1) {
        var px = x0;
        while (px < x1) : (px += 1) {
            writePixel32(px, py, color);
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
    while (px < cx1) : (px += 1) {
        writePixel32(px, y, color);
    }
}

fn drawVerticalLine(x: u32, y0: u32, y1: u32, color: u32) void {
    if (x >= SCREEN_W) return;
    if (y1 <= y0) return;

    const cy0 = if (y0 > SCREEN_H) SCREEN_H else y0;
    const cy1 = if (y1 > SCREEN_H) SCREEN_H else y1;
    if (cy1 <= cy0) return;

    var py = cy0;
    while (py < cy1) : (py += 1) {
        writePixel32(x, py, color);
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
    return @as(usize, @intCast(ty * GRID_W + tx));
}

fn setTile(tx: u32, ty: u32, kind: TileKind) void {
    if (tx >= GRID_W or ty >= GRID_H) return;
    world_tiles[tileIndex(tx, ty)] = kind;
}

export fn render() void {
    var ty: u32 = 0;
    while (ty < GRID_H) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < GRID_W) : (tx += 1) {
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

    drawRectOutline(player1.pos.x, player1.pos.y, player1.w, player1.h, player1.color);
}

export fn init() void {
    var ty: u32 = 0;
    while (ty < GRID_H) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < GRID_W) : (tx += 1) {
            const use_light = ((tx + ty) & 1) == 0;
            setTile(tx, ty, if (use_light) .light else .dark);
        }
    }
}
