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

const enemies = @import("../enemies/enemies.zig");

const BG = colors.C64_BLACK;
var last_input: input.Layout = .{
    .buttons_lo = 0,
    .buttons_hi = 0,
    ._reserved = 0,
    .mouse_x = 0,
    .mouse_y = 0,
    .mouse_buttons = 0,
};
const Cursor = struct { now: u32, last_move: u32 };

const Actor = struct { tile: u16, kind: enemies.Kind };
fn actorTileX(actor: Actor) u32 {
    return @as(u32, actor.tile) % maps.BATTLE_MAP_WIDTH;
}

fn actorTileY(actor: Actor) u32 {
    return @as(u32, actor.tile) / maps.BATTLE_MAP_WIDTH;
}
const BattleState = struct {
    cursor: Cursor = .{ .now = 0, .last_move = 0 },
    rng: u32 = 0,
    actors: [16]Actor = undefined,
    actor_count: usize = 0,
    active_tile: u32 = 0,

    pub fn reset(self: *BattleState) void {
        self.cursor = .{ .now = 0, .last_move = 0 };
        self.rng = 0;
        self.actor_count = 0;
        self.active_tile = 0;
    }
};
var state = BattleState{};

fn rand() u32 {
    state.rng = state.rng *% 1664525 +% 1013904223;
    return state.rng;
}

pub const EncounterConfig = struct {
    groups: encounters.Encounter,
    seed: u32,
};
pub const BattleDef = struct {
    tile_mapping: maps.TileMapping,
    pattern_map: maps.PatternMap,
    encounter_config: []const EncounterConfig,
};

pub fn spawnEncounter(encounter: encounters.Encounter, seed: u32) void {
    state.rng = seed;

    for (encounter) |spawn| {
        var i: usize = 0;
        while (i < @as(usize, spawn.quantity) and state.actor_count < state.actors.len) : (i += 1) {
            const tx = 16 + rand() % 16;
            const ty = rand() % 16;
            const tile = ty * maps.BATTLE_MAP_WIDTH + tx;
            state.actors[state.actor_count] = .{
                .tile = @intCast(tile),
                .kind = spawn.kind,
            };

            state.actor_count += 1;
        }
    }
}
pub fn init(battle_def: BattleDef) void {
    maps.loadMap(battle_def.pattern_map, battle_def.tile_mapping);

    state.reset();
    for (battle_def.encounter_config) |config| {
        spawnEncounter(config.groups, config.seed);
    }
}
fn cursorTileX() u32 {
    return state.cursor.now % maps.BATTLE_MAP_WIDTH;
}

fn cursorTileY() u32 {
    return state.cursor.now / maps.BATTLE_MAP_WIDTH;
}
pub fn input_cursor(input_data: input.Layout) void {
    state.cursor.last_move += 1;
    if ((input_data.buttons_lo & input.BTN_LEFT) != 0 and
        cursorTileX() > 0 and
        state.cursor.last_move > 16)
    {
        state.cursor.now -= 1;
        state.cursor.last_move = 0;
    }

    if ((input_data.buttons_lo & input.BTN_RIGHT) != 0 and
        cursorTileX() < maps.BATTLE_MAP_WIDTH - 1 and
        state.cursor.last_move > 16)
    {
        state.cursor.now += 1;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_UP) != 0 and state.cursor.now > maps.BATTLE_MAP_WIDTH - 1 and state.cursor.last_move > 16) {
        state.cursor.now -= maps.BATTLE_MAP_WIDTH;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_DOWN) != 0 and state.cursor.now < maps.BATTLE_MAP_LENGTH - maps.BATTLE_MAP_WIDTH and state.cursor.last_move > 16) {
        state.cursor.now += maps.BATTLE_MAP_WIDTH;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_A) != 0) {
        state.active_tile = state.cursor.now;
    }
    // if ((input_data.buttons_lo & input.BTN_B) != 0) {}
    // if ((input_data.buttons_lo & input.BTN_X) != 0) {}
    // if ((input_data.buttons_lo & input.BTN_Y) != 0) {}
    if ((input_data.buttons_hi & input.BTN_SELECT) != 0) {
        scene.request(.menu);
    }

    last_input = input_data;
}
pub fn tick(input_data: input.Layout) void {
    input_cursor(input_data);
}

fn render_tiles() void {
    var ty: u32 = 0;
    while (ty < maps.BATTLE_MAP_HEIGHT) : (ty += 1) {
        var tx: u32 = 0;
        while (tx < maps.BATTLE_MAP_WIDTH) : (tx += 1) {
            const x = tx * grid.TILE_SIZE;
            const y = ty * grid.TILE_SIZE;
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
    var i: usize = 0;
    while (i < state.actor_count) : (i += 1) {
        const actor = state.actors[i];
        const enemy = enemies.get(actor.kind);
        renderer.drawBitmap8x8Mono(
            actorTileX(actor) * grid.TILE_SIZE,
            actorTileY(actor) * grid.TILE_SIZE,
            enemy.pattern,
            enemy.color,
        );
    }
}
fn cursorX() u32 {
    return (state.cursor.now % maps.BATTLE_MAP_WIDTH) * grid.TILE_SIZE;
}

fn cursorY() u32 {
    return (state.cursor.now / maps.BATTLE_MAP_WIDTH) * grid.TILE_SIZE;
}
pub fn render() void {
    ui.clearScreen(BG);
    render_tiles();

    font.drawString(0 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, "ENEMIES", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(9 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, &ui.u999ToChars(@intCast(state.actor_count)), colors.C64_CYAN, colors.C64_BLACK);

    const position = ui.u999ToChars(state.active_tile);
    font.drawString(37 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, &position, colors.C64_LIGHT_BLUE, colors.C64_BLACK);

    render_actors();
    renderer.drawRectOutline(0, 0, grid.TILE_SIZE * maps.BATTLE_MAP_WIDTH, grid.TILE_SIZE * maps.BATTLE_MAP_HEIGHT, colors.C64_DARK_GRAY);

    renderer.drawRectOutline(cursorX(), cursorY(), grid.TILE_SIZE, grid.TILE_SIZE, colors.C64_YELLOW);
}
