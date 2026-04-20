extern "env" fn console_log(value: u32) void;

// TILEMAP

/// The tile size will always be 8. For larger sprites we use 2x8 or 4x8 tiles, but the basic unit is 8 pixels.
/// This keeps calculations simple and close to retro aesthetics.
const TILE_SIZE: u32 = 8;
/// We use 16 tiles for now. It's just a nice number that somewhat fits retro resolutions and allows for a simple grid-based world. This means our world will be 128 pixels wide (16 tiles * 8 pixels per tile).
const GRID_W: u32 = 16;
/// We use 12 tiles for now. It's just a nice number that somewhat fits retro resolutions and allows for a simple grid-based world. This means our world will be 96 pixels high (12 tiles * 8 pixels per tile).
const GRID_H: u32 = 12;

// SCREEN

/// 128 = 8 * 16. 128 is somewhat close to retro resolutions
const SCREEN_W: u32 = GRID_W * TILE_SIZE;
/// Exported for calculations in JS (Width);
export fn width() i32 {
    return SCREEN_W;
}

/// 96 = 8 * 12. 96 is somewhat close to retro resolutions
const SCREEN_H: u32 = GRID_H * TILE_SIZE;
/// Exported for calculations in JS (Height);
export fn height() i32 {
    return SCREEN_H;
}

/// The raw amoung of pixels in the frame buffer, used for JS memory management.
const FRAME_PIXELS: usize = @as(usize, SCREEN_W * SCREEN_H);
/// Zig allocates this in module memory; JS can query its base via `framePtr()`.
export var frame_buffer: [FRAME_PIXELS]u32 = undefined;
/// Exports the byte offset of the frame buffer for JS to write pixel data into.
export fn framePtr() u32 {
    return @as(u32, @intCast(@intFromPtr(&frame_buffer[0])));
}
/// Exports the byte length of the frame buffer for JS memory management.
export fn frameLen() u32 {
    return @sizeOf(@TypeOf(frame_buffer));
}

// INPUT

/// The number of keys we plan to track
const INPUT_KEY_COUNT: usize = 8;

/// C-layout struct for input data, written to by JS.
/// The `extern` attribute ensures C-compatible layout and stable byte offsets.
const InputData = extern struct {
    keys: [INPUT_KEY_COUNT]u8,
    mouse_x: u32,
    mouse_y: u32,
    mouse_buttons: u32,
};

/// C-layout input block keeps byte offsets stable for JS DataView writes.
/// JS writes input state into this struct each frame, and Zig reads from it in `tick()`.
export var input_data: InputData = .{
    .keys = [_]u8{0} ** INPUT_KEY_COUNT,
    .mouse_x = 0,
    .mouse_y = 0,
    .mouse_buttons = 0,
};

/// Exports the byte offset of the input data block for JS to write input state into.
export fn inputPtr() u32 {
    return @as(u32, @intCast(@intFromPtr(&input_data)));
}
/// Exports the byte length of the input data block for JS memory management.
export fn inputLen() u32 {
    return @sizeOf(InputData);
}

/// Mouse button bitmask values shared with JS.
const MOUSE_BUTTON_LEFT: u32 = 1;
const MOUSE_BUTTON_RIGHT: u32 = 4;

/// ATTENTION: THESE SHOULD NOT BE WRITTEN TO BY ZIG.
/// Mouse coordinate (x)
export fn mouse_x() u32 {
    return input_data.mouse_x;
}

/// Mouse coordinate (y)
export fn mouse_y() u32 {
    return input_data.mouse_y;
}

/// Mouse button state as a bitmask (left=1, middle=2, right=4).
export fn mouse_buttons() u32 {
    return input_data.mouse_buttons;
}

// 2D GEOMETRY

/// The classic Point struct, used for two-dimensional positions.
const Point = struct {
    x: u32,
    y: u32,
};

/// The other classic struct, a rectangle defined by its top-left corner and dimensions. Used for drawing and collision.
const Rect: type = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

// PLAYABLE CHARACTER(S)

/// Player is a simple struct that holds what we need to know about the player character: its position, color, and dimensions. For now, it's just a rectangle that we draw on the screen, but we can easily expand it later with more properties like velocity, health, etc.
const Player: type = struct {
    pos: Point,
    color: u32,
    h: u32 = 8,
    w: u32 = 8,
};

/// We only have one player for now. Could be party of players later.
var player1: Player = Player{
    .pos = Point{ .x = 60, .y = 40 },
    .color = C64_BLUE,
};

// TILES

/// Extensible tile types for our tilemap. For now, we have just three: light, dark, and wall.
/// We can easily add more later if we want to expand the world with different terrain types, items, etc.
const TileKind = enum(u8) {
    light,
    dark,
    wall,
};

/// The world is represented as a flat array of tiles. We calculate the index based on tile coordinates (tx, ty) using the tileIndex function. This allows us to easily access and modify the tile data for our grid-based world.
const GRID_LEN: usize = @as(usize, GRID_W * GRID_H);
/// Initialize the world with all dark tiles. We can change this later in the init() function to create a more interesting world layout. For now, it's just a simple checkerboard pattern of light and dark tiles.
var world_tiles: [GRID_LEN]TileKind = [_]TileKind{.dark} ** GRID_LEN;

/// Helper function to calculate the index in the world_tiles array based on tile coordinates. This allows us to easily access and modify the tile data for our grid-based world.
fn tileIndex(tx: u32, ty: u32) usize {
    return @as(usize, @intCast(ty * GRID_W + tx));
}

/// Sets the tile at the given tile coordinates (tx, ty) to the specified kind. It includes bounds checking to ensure we don't write out of bounds in the world_tiles array.
fn setTile(tx: u32, ty: u32, kind: TileKind) void {
    if (tx >= GRID_W or ty >= GRID_H) return;
    world_tiles[tileIndex(tx, ty)] = kind;
}

/// Tick is used for simulation.
/// It should run either round-based or whatever is appropriate for the game.
/// Most games do less ticks than renders.
export fn tick() void {
    const mousex = input_data.mouse_x;
    const mousey = input_data.mouse_y;
    const mousebuttons = input_data.mouse_buttons;

    if (mousebuttons > 0) {
        const tx = if (mousex >= SCREEN_W) (GRID_W - 1) else (mousex / TILE_SIZE);
        const ty = if (mousey >= SCREEN_H) (GRID_H - 1) else (mousey / TILE_SIZE);

        if ((mousebuttons & MOUSE_BUTTON_LEFT) != 0) {
            setTile(tx, ty, .wall);
        }
        if ((mousebuttons & MOUSE_BUTTON_RIGHT) != 0) {
            setTile(tx, ty, .light);
        }
    }
}

// RENDERING

/// Packs RGBA channels into one 32-bit pixel.
fn rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    // In wasm32 little-endian memory this is laid out as [R, G, B, A], matching ImageData.
    return @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16) | (@as(u32, a) << 24);
}

/// Writes one 32-bit pixel into the frame buffer.
fn writePixel32(x: u32, y: u32, color: u32) void {
    if (x >= SCREEN_W or y >= SCREEN_H) return;
    const index = @as(usize, @intCast(y * SCREEN_W + x));
    frame_buffer[index] = color;
}

/// Simple function to fill a rectangle area with a color.
/// It handles clipping to the screen bounds and ensures we don't write out of bounds in the frame buffer.
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

/// Draws a horizontal line. It handles clipping to the screen bounds and ensures we don't write out of bounds in the frame buffer.
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

/// Draws a vertical line. It handles clipping to the screen bounds and ensures we don't write out of bounds in the frame buffer.
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

/// Draws a rectangle outline by drawing four lines. It handles clipping to the screen bounds and ensures we don't write out of bounds in the frame buffer.
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

/// The main render function that draws the current game state to the frame buffer.
/// This function is called every frame to update the visuals.
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

// INITIALIZATION

/// Initializes the game state. This function is called once at the start of the game to set up the initial world and any necessary data structures.
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
