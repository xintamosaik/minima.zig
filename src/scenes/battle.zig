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
pub fn tick(input_data: input.Layout) void {
    if (!loaded) {
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
                    .x = actor_index,
                    .y = actor_index,
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

    const buttons_lo = input_data.buttons_lo;
    const buttons_hi = input_data.buttons_hi;

    // move around cursor
    cursor.last_move += 1;
    if ((buttons_lo & input.BTN_LEFT) != 0 and cursor.now > 0 and cursor.last_move > 16) {
        cursor.now -= 1;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_RIGHT) != 0 and cursor.now < LENGTH - 1 and cursor.last_move > 16) {
        cursor.now += 1;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_UP) != 0 and cursor.now > WIDTH - 1 and cursor.last_move > 16) {
        cursor.now -= WIDTH;
        cursor.last_move = 0;
    }
    if ((buttons_lo & input.BTN_DOWN) != 0 and cursor.now < LENGTH - WIDTH and cursor.last_move > 16) {
        cursor.now += WIDTH;
        cursor.last_move = 0;
    }

    // Buttons

    // A
    if ((buttons_lo & input.BTN_A) != 0) {
        active = cursor.now;
    }

    // B
    if ((buttons_lo & input.BTN_B) != 0) {}

    // X
    if ((buttons_lo & input.BTN_X) != 0) {}

    // Y
    if ((buttons_lo & input.BTN_Y) != 0) {}

    if ((buttons_hi & input.BTN_SELECT) != 0) {
        scene.scene = .menu;
    }
}
var cur_x: u32 = 0;
var cur_y: u32 = 0;
pub fn render() void {
    ui.clearScreen(BG);
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

    font.drawString(0 * TILE_SIZE, 24 * TILE_SIZE, "BARBARIAN", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(32 * TILE_SIZE, 0 * TILE_SIZE, "HP:  120", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(32 * TILE_SIZE, 1 * TILE_SIZE, "AP:    9", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(32 * TILE_SIZE, 4 * TILE_SIZE, "STATUS", colors.C64_WHITE, colors.C64_BLACK);
    font.drawString(32 * TILE_SIZE, 5 * TILE_SIZE, "POISON", colors.C64_LIGHT_GREEN, colors.C64_BLACK);
    const position = ui.u999ToChars(active);
    font.drawString(37 * TILE_SIZE, 24 * TILE_SIZE, &position, colors.C64_LIGHT_BLUE, colors.C64_BLACK);
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
    renderer.drawBitmap8x8(8 * 5, 8 * 7, patterns_enemy.GOBLIN, colors.C64_GREEN, colors.C64_BLACK);

    renderer.drawRectOutline(0, 0, TILE_SIZE * 32, TILE_SIZE * 24, colors.C64_DARK_GRAY);

    renderer.drawRectOutline(cur_x, cur_y, TILE_SIZE, TILE_SIZE, colors.C64_YELLOW);
}
