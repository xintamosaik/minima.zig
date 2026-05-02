extern "env" fn console_log(value: u32) void;

const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const colors = @import("../colors.zig");
const font = @import("../font.zig");
const ui = @import("../ui.zig");
const maps = @import("../maps/maps.zig");
const grid = @import("../grid.zig");

const patterns_outside = @import("../patterns/outside.zig");
const patterns_general = @import("../patterns/general.zig");
const patterns_enemy = @import("../patterns/enemy.zig");

const plain = @import("../maps/battle/plain.zig");

const enemies = @import("../enemies/enemies.zig");
const wolfpack = @import("../encounters/pack_of_wolves.zig");
const goblingroup = @import("../encounters/goblin_group.zig");

const TILE_SIZE: u32 = 8;
const WIDTH: u32 = 40;
const HEIGHT: u32 = 25;
const LENGTH = WIDTH * HEIGHT;

const BG = colors.C64_BLACK;

const Cursor = struct { now: u32, former: u32, last_move: u32 };
var cursor = Cursor{ .now = 0, .former = 0, .last_move = 0 };
var rng_state: u32 = 0x12345678;

fn rand() u32 {
    rng_state = rng_state *% 1664525 +% 1013904223;
    return rng_state;
}
const Actor = struct { x: u32, y: u32, color: u32, type: enemies.Enemies, active: bool = false };
var actors: [16]Actor = undefined;
const tile_mapping = maps.TileMapping{
    .base = .empty,
    .a = .dirt,
    .b = .water,
};

var active: u32 = 0;
var loaded = false;
var actor_index: u32 = 0;

pub fn init() void {
    maps.loadMap(.{
        .a = plain.A,
        .b = plain.B,
    }, tile_mapping);

    for (wolfpack.spawn) |spawn| {
        const group = spawn;

        var i: u8 = 0;
        while (i < group.quantity) {
            i = i + 1;

            actors[actor_index] = .{
                .x = 16 + rand() % 16,
                .y = rand() % 16,
                .color = switch (spawn.enemy.kind) {
                    .wolf => enemies.wolf.color,
                    .goblin => enemies.goblin.color,
                },
                .type = spawn.enemy.kind,
                .active = true,
            };
            actor_index = actor_index + 1;
        }
    }
    rng_state = 0x87654321;
    for (goblingroup.spawn) |spawn| {
        const group = spawn;

        var i: u8 = 0;
        while (i < group.quantity) {
            i = i + 1;

            actors[actor_index] = .{
                .x = 16 + rand() % 16,
                .y = rand() % 16,
                .color = switch (spawn.enemy.kind) {
                    .wolf => enemies.wolf.color,
                    .goblin => enemies.goblin.color,
                },
                .type = spawn.enemy.kind,
                .active = true,
            };
            actor_index = actor_index + 1;
        }
    }
    loaded = true;
}
pub fn input_cursor(input_data: input.Layout) void {
    cursor.last_move += 1;
    if ((input_data.buttons_lo & input.BTN_LEFT) != 0 and cursor.now > 0 and cursor.last_move > 16) {
        cursor.now -= 1;
        cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_RIGHT) != 0 and cursor.now < LENGTH - 1 and cursor.last_move > 16) {
        cursor.now += 1;
        cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_UP) != 0 and cursor.now > WIDTH - 1 and cursor.last_move > 16) {
        cursor.now -= WIDTH;
        cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_DOWN) != 0 and cursor.now < LENGTH - WIDTH and cursor.last_move > 16) {
        cursor.now += WIDTH;
        cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_A) != 0) {
        active = cursor.now;
    }
    // if ((input_data.buttons_lo & input.BTN_B) != 0) {}
    // if ((input_data.buttons_lo & input.BTN_X) != 0) {}
    // if ((input_data.buttons_lo & input.BTN_Y) != 0) {}
    if ((input_data.buttons_hi & input.BTN_SELECT) != 0) {
        scene.scene = .menu;
    }
}
pub fn tick(input_data: input.Layout) void {
    if (!loaded) init();
    input_cursor(input_data);
}

var cur_x: u32 = 0;
var cur_y: u32 = 0;

fn render_tiles() void {
    var ty: u32 = 0;
    while (ty < HEIGHT) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < WIDTH) : (tx += 1) {
            const x = tx * TILE_SIZE;
            const y = ty * TILE_SIZE;
            const kind = grid.getTile(tx, ty);
            const color = switch (kind) {
                .wall => colors.C64_DARK_GRAY,
                .dirt => colors.C64_BROWN,
                .stone => colors.C64_PURPLE,
                .water => colors.C64_LIGHT_BLUE,
                .grass => colors.C64_GREEN,
                .empty => colors.C64_BLACK,
            };

            const pattern = switch (kind) {
                .grass => patterns_outside.GRASS,
                .water => patterns_outside.WATER,
                .dirt => patterns_outside.DIRT,
                .stone => patterns_outside.STONE,
                .wall => patterns_outside.WALL,
                .empty => patterns_general.EMPTY,
            };

            renderer.drawBitmap8x8(x, y, pattern, color, colors.C64_BLACK);
            const gridPosition = grid.tileIndex(tx, ty);
            if (gridPosition == cursor.now) {
                cur_x = x;
                cur_y = y;
            }
        }
    }
}
fn render_actors() void {
    var i: u32 = 0;
    while (i < actor_index) : (i += 1) {
        const actor = actors[i];

        if (!actor.active) continue;

        renderer.drawBitmap8x8Mono(
            actor.x * TILE_SIZE,
            actor.y * TILE_SIZE,
            switch (actor.type) {
                .wolf => patterns_enemy.WOLF,
                .goblin => patterns_enemy.GOBLIN,
            },
            actor.color,
        );
    }
}
pub fn render() void {
    ui.clearScreen(BG);
    render_tiles();

    font.drawString(0 * TILE_SIZE, 24 * TILE_SIZE, "ENEMIES", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(9 * TILE_SIZE, 24 * TILE_SIZE, &ui.u999ToChars(actor_index), colors.C64_CYAN, colors.C64_BLACK);

    const position = ui.u999ToChars(active);
    font.drawString(37 * TILE_SIZE, 24 * TILE_SIZE, &position, colors.C64_LIGHT_BLUE, colors.C64_BLACK);

    render_actors();
    renderer.drawRectOutline(0, 0, TILE_SIZE * 32, TILE_SIZE * 24, colors.C64_DARK_GRAY);

    renderer.drawRectOutline(cur_x, cur_y, TILE_SIZE, TILE_SIZE, colors.C64_YELLOW);
}
