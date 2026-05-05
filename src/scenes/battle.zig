extern "env" fn console_log(value: u32) void;

const input = @import("../input.zig");
const renderer = @import("../render.zig");
const scene = @import("../scene.zig");
const maps = @import("../maps/maps.zig");
const colors = @import("../colors.zig");
const font = @import("../font.zig");
const ui = @import("../ui.zig");
const grid = @import("../grid.zig");
const encounters = @import("../encounters/encounter.zig");
const patterns_outside = @import("../patterns/outside.zig");
const patterns_general = @import("../patterns/general.zig");
const patterns_enemy = @import("../patterns/enemy.zig");

const enemies = @import("../enemies/enemies.zig");

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
const Actor = struct { x: u32, y: u32, color: u32, kind: enemies.Enemies, active: bool = false };
var actors: [16]Actor = undefined;
pub const EncounterConfig = struct {
    group: encounters.Encounter,
    seed: u32,
};
pub const BattleDef = struct {
    tile_mapping: maps.TileMapping,
    pattern_map: maps.PatternMap,
    encounter_config: []const EncounterConfig,
};

var active: u32 = 0;
var loaded = false;
var actor_count: u32 = 0;
pub fn spawnEncounter(encounter: anytype, seed: u32) void {
    rng_state = seed;

    for (encounter) |spawn| {
        var i: u8 = 0;
        while (i < spawn.quantity and actor_count < actors.len) : (i += 1) {
            actors[actor_count] = .{
                .x = 16 + rand() % 16,
                .y = rand() % 16,
                .color = switch (spawn.enemy.kind) {
                    .wolf => enemies.wolf.color,
                    .goblin => enemies.goblin.color,
                },
                .kind = spawn.enemy.kind,
                .active = true,
            };

            actor_count += 1;
        }
    }
}
pub fn init(battle_def: BattleDef) void {
    maps.loadMap(battle_def.pattern_map, battle_def.tile_mapping);

    actor_count = 0;
    for (battle_def.encounter_config) |config| {
        spawnEncounter(config.group, config.seed);
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
    input_cursor(input_data);
}

 

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
 
        }
    }
}
fn render_actors() void {
    var i: u32 = 0;
    while (i < actor_count) : (i += 1) {
        const actor = actors[i];

        if (!actor.active) continue;

        renderer.drawBitmap8x8Mono(
            actor.x * TILE_SIZE,
            actor.y * TILE_SIZE,
            switch (actor.kind) {
                .wolf => patterns_enemy.WOLF,
                .goblin => patterns_enemy.GOBLIN,
            },
            actor.color,
        );
    }
}
fn cursorX() u32 {
    return (cursor.now % WIDTH) * TILE_SIZE;
}

fn cursorY() u32 {
    return (cursor.now / WIDTH) * TILE_SIZE;
}
pub fn render() void {
    ui.clearScreen(BG);
    render_tiles();

    font.drawString(0 * TILE_SIZE, 24 * TILE_SIZE, "ENEMIES", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(9 * TILE_SIZE, 24 * TILE_SIZE, &ui.u999ToChars(actor_count), colors.C64_CYAN, colors.C64_BLACK);

    const position = ui.u999ToChars(active);
    font.drawString(37 * TILE_SIZE, 24 * TILE_SIZE, &position, colors.C64_LIGHT_BLUE, colors.C64_BLACK);

    render_actors();
    renderer.drawRectOutline(0, 0, TILE_SIZE * 32, TILE_SIZE * 24, colors.C64_DARK_GRAY);

    renderer.drawRectOutline(cursorX(), cursorY(), TILE_SIZE, TILE_SIZE, colors.C64_YELLOW);
}
