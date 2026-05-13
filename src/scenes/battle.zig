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
const heroes = @import("../heroes.zig");
const enemies = @import("../enemies/enemies.zig");

const BG = colors.C64_BLACK;
const HERO_COLOR = colors.C64_LIGHT_GRAY;
const HERO_ACTIVE_COLOR = colors.C64_YELLOW;

const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

var last_input: input.Layout = .{
    .buttons_lo = 0,
    .buttons_hi = 0,
    ._reserved = 0,
    .mouse_x = 0,
    .mouse_y = 0,
    .mouse_buttons = 0,
};

const Cursor = struct { now: u16, last_move: u8 };

const Actor = struct { tile: u16, kind: enemies.Kind };

fn tile2X(tile: u16) u32 {
    return @as(u32, tile) % maps.BATTLE_MAP_WIDTH;
}
fn tile2Y(tile: u16) u32 {
    return @as(u32, tile) / maps.BATTLE_MAP_WIDTH;
}

var selected_hero: usize = 0;

const BattleState = struct {
    cursor: Cursor = .{ .now = 0, .last_move = 0 },
    rng: u32 = 0,
    actors: [16]Actor = undefined,
    actor_count: usize = 0,
    active_tile: u16 = 0,
    hero_positions: [4]u16 = undefined,

    currentMoveRect: Rect = .{
        .x = 0,
        .y = 0,
        .w = 0,
        .h = 0,
    },
    pub fn reset(self: *BattleState) void {
        self.cursor = .{ .now = 0, .last_move = 0 };
        self.rng = 0;
        self.actor_count = 0;
        self.active_tile = 0;
        self.currentMoveRect = .{
            .x = 0,
            .y = 0,
            .w = 0,
            .h = 0,
        };
        self.hero_positions = undefined;
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
fn heroAt(tile: u16) bool {
    for (state.hero_positions) |pos| {
        if (pos == tile) return true;
    }
    return false;
}
fn actorAt(tile: u16) bool {
    var i: usize = 0;
    while (i < state.actor_count) : (i += 1) {
        if (state.actors[i].tile == tile) return true;
    }
    return false;
}

fn trySpawnActor(kind: enemies.Kind, tile: u16) bool {
    if (state.actor_count >= state.actors.len) return false;
    if (@as(u32, tile) >= maps.BATTLE_MAP_LENGTH) return false;

    if (actorAt(tile)) return false;
    if (heroAt(tile)) return false;

    const tx = tile2X(tile);
    const ty = tile2Y(tile);

    if (!grid.isPassable(grid.getTile(tx, ty))) return false;

    state.actors[state.actor_count] = .{
        .tile = tile,
        .kind = kind,
    };
    state.actor_count += 1;

    return true;
}

fn randBelow(max: u32) u32 {
    return ((rand() >> 16) * max) >> 16;
}
const HALF_WIDTH = maps.BATTLE_MAP_WIDTH / 2;
pub fn spawnEncounter(encounter: encounters.Encounter, seed: u32) void {
    state.rng = seed;

    for (encounter) |spawn| {
        var spawned: usize = 0;
        var attempts: usize = 0;

        const max_attempts = @as(usize, spawn.quantity) * 16;

        while (spawned < @as(usize, spawn.quantity) and
            attempts < max_attempts and
            state.actor_count < state.actors.len) : (attempts += 1)
        {
            const tx = HALF_WIDTH + randBelow(HALF_WIDTH);
            const ty = randBelow(maps.BATTLE_MAP_HEIGHT);
            const tile = ty * maps.BATTLE_MAP_WIDTH + tx;

            if (trySpawnActor(spawn.kind, @intCast(tile))) {
                spawned += 1;
            }
        }
    }
}
pub fn init(battle_def: BattleDef) void {
    maps.loadMap(battle_def.pattern_map, battle_def.tile_mapping);

    state.reset();
    for (battle_def.encounter_config) |config| {
        spawnEncounter(config.groups, config.seed);
    }

    var i: u8 = 0;
    while (i < heroes.party.len) {
        state.hero_positions[i] = i;
        i = i + 1;
    }
}
fn heroIndexAt(tile: u16) ?u16 {
    var i: u8 = 0;
    while (i < heroes.party.len) {
        if (state.hero_positions[i] == tile) {
            return tile;
        }
        i = i + 1;
    }

    return null;
}
const CURSOR_SLOW_DOWN = 8;
pub fn input_cursor(input_data: input.Layout) void {
    state.cursor.last_move +%= 1;
    if ((input_data.buttons_lo & input.BTN_LEFT) != 0 and
        tile2X(state.cursor.now) > 0 and
        (state.cursor.last_move > CURSOR_SLOW_DOWN or
            (last_input.buttons_lo & input.BTN_LEFT) == 0))
    {
        state.cursor.now -= 1;
        state.cursor.last_move = 0;
    }

    if ((input_data.buttons_lo & input.BTN_RIGHT) != 0 and
        tile2X(state.cursor.now) < maps.BATTLE_MAP_WIDTH - 1 and
        (state.cursor.last_move > CURSOR_SLOW_DOWN or
            (last_input.buttons_lo & input.BTN_RIGHT) == 0))
    {
        state.cursor.now += 1;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_UP) != 0 and state.cursor.now > maps.BATTLE_MAP_WIDTH - 1 and (state.cursor.last_move > CURSOR_SLOW_DOWN or (last_input.buttons_lo & input.BTN_UP) == 0)) {
        state.cursor.now -= maps.BATTLE_MAP_WIDTH;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_DOWN) != 0 and state.cursor.now < maps.BATTLE_MAP_LENGTH - maps.BATTLE_MAP_WIDTH and (state.cursor.last_move > CURSOR_SLOW_DOWN or (last_input.buttons_lo & input.BTN_DOWN) == 0)) {
        state.cursor.now += maps.BATTLE_MAP_WIDTH;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_A) != 0) {
        state.active_tile = state.cursor.now;
        if (heroIndexAt(state.active_tile)) |index| {
            selected_hero = index;
            state.currentMoveRect = movementRectForHero(index, heroes.party[selected_hero].moveRadius);
        }
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

            renderer.drawBitmap8x8Mono(x, y, pattern, color);
        }
    }
}

fn render_hero(index: usize, label: u8) void {
    const color = if (index == selected_hero) HERO_ACTIVE_COLOR else HERO_COLOR;

    font.drawMono(
        tile2X(state.hero_positions[index]) * grid.TILE_SIZE,
        tile2Y(state.hero_positions[index]) * grid.TILE_SIZE,
        label,
        color,
    );
}
fn enemyNameAt(tile: u16) []const u8 {
    var i: usize = 0;
    while (i < state.actor_count) : (i += 1) {
        const actor = state.actors[i];

        if (actor.tile != tile) continue;

        return switch (actor.kind) {
            .wolf => "WOLF",
            .goblin => "GOBLIN",
        };
    }

    return "";
}
fn render_actors() void {
    var i: usize = 0;
    while (i < state.actor_count) : (i += 1) {
        const actor = state.actors[i];
        const enemy = enemies.get(actor.kind);
        renderer.drawBitmap8x8Mono(
            tile2X(actor.tile) * grid.TILE_SIZE,
            tile2Y(actor.tile) * grid.TILE_SIZE,
            enemy.pattern,
            enemy.color,
        );
    }
}
fn activeTileKind() grid.TileKind {
    return grid.getTile(tile2X(state.active_tile), tile2Y(state.active_tile));
}

fn heroNameAt(tile: u16) []const u8 {
    var i: u8 = 0;
    while (i < heroes.party.len) {
        if (state.hero_positions[i] == tile) {
            return heroes.party[i].name;
        }
        i = i + 1;
    }

    return "";
}

fn render_tile_info() void {
    const currentTile = activeTileKind();
    const tileLabel = switch (currentTile) {
        .dirt => "dirt",
        .empty => "none",
        .grass => "grass",
        .stone => "stone",
        .wall => "wall",
        .water => "water",
    };

    font.drawString(
        32 * grid.TILE_SIZE,
        0 * grid.TILE_SIZE,
        tileLabel,
        colors.C64_CYAN,
        colors.C64_BLACK,
    );

    const hero_name = heroNameAt(state.active_tile);
    const enemy_name = enemyNameAt(state.active_tile);

    const actor_type: []const u8 =
        if (hero_name.len > 0)
            "hero"
        else if (enemy_name.len > 0)
            "enemy"
        else
            "";

    const actor_name: []const u8 =
        if (hero_name.len > 0)
            hero_name
        else
            enemy_name;

    font.drawString(
        32 * grid.TILE_SIZE,
        2 * grid.TILE_SIZE,
        actor_type,
        colors.C64_LIGHT_GRAY,
        colors.C64_BLACK,
    );

    font.drawString(
        32 * grid.TILE_SIZE,
        3 * grid.TILE_SIZE,
        actor_name,
        colors.C64_YELLOW,
        colors.C64_BLACK,
    );

    font.drawString(
        32 * grid.TILE_SIZE,
        5 * grid.TILE_SIZE,
        "MOVES",
        colors.C64_LIGHT_GRAY,
        colors.C64_BLACK,
    );

    font.drawMono(
        38 * grid.TILE_SIZE,
        5 * grid.TILE_SIZE,
        '0' + @as(u8, heroes.party[selected_hero].moveRadius),
        colors.C64_YELLOW,
    );
}

fn movementRectForHero(hero: u16, radius: u4) Rect {
    const heroTileX = tile2X(state.hero_positions[hero]);
    const heroTileY = tile2Y(state.hero_positions[hero]);

    const minTileX = heroTileX -| radius;
    const minTileY = heroTileY -| radius;

    const maxTileX = @min(heroTileX + radius, maps.BATTLE_MAP_WIDTH - 1);
    const maxTileY = @min(heroTileY + radius, maps.BATTLE_MAP_HEIGHT - 1);

    return .{
        .x = minTileX * grid.TILE_SIZE,
        .y = minTileY * grid.TILE_SIZE,
        .w = (maxTileX - minTileX + 1) * grid.TILE_SIZE,
        .h = (maxTileY - minTileY + 1) * grid.TILE_SIZE,
    };
}
pub fn render() void {
    ui.clearScreen(BG);
    renderer.drawRectOutline(
        state.currentMoveRect.x,
        state.currentMoveRect.y,
        state.currentMoveRect.w,
        state.currentMoveRect.h,
        colors.C64_CYAN,
    );
    render_tiles();

    font.drawString(0 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, "ENEMIES", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(9 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, &ui.u999ToChars(@intCast(state.actor_count)), colors.C64_CYAN, colors.C64_BLACK);

    const position = ui.u999ToChars(state.active_tile);
    font.drawString(32 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 2) * grid.TILE_SIZE, "POS", colors.C64_LIGHT_BLUE, colors.C64_BLACK);
    font.drawString(37 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 2) * grid.TILE_SIZE, &position, colors.C64_LIGHT_BLUE, colors.C64_BLACK);

    const activeX = ui.u999ToChars(tile2X(state.active_tile));
    font.drawString(32 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 1) * grid.TILE_SIZE, "X", colors.C64_LIGHT_RED, colors.C64_BLACK);
    font.drawString(37 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 1) * grid.TILE_SIZE, &activeX, colors.C64_LIGHT_RED, colors.C64_BLACK);

    const activeY = ui.u999ToChars(tile2Y(state.active_tile));
    font.drawString(32 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, "Y", colors.C64_LIGHT_GREEN, colors.C64_BLACK);
    font.drawString(37 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, &activeY, colors.C64_LIGHT_GREEN, colors.C64_BLACK);

    render_actors();

    render_hero(0, '1');
    render_hero(1, '2');
    render_hero(2, '3');
    render_hero(3, '4');

    renderer.drawRectOutline(0, 0, grid.TILE_SIZE * maps.BATTLE_MAP_WIDTH, grid.TILE_SIZE * maps.BATTLE_MAP_HEIGHT, colors.C64_DARK_GRAY);
    renderer.drawRectOutline(tile2X(state.cursor.now) * grid.TILE_SIZE, tile2Y(state.cursor.now) * grid.TILE_SIZE, grid.TILE_SIZE, grid.TILE_SIZE, colors.C64_YELLOW);
    renderer.drawRectOutline(tile2X(state.active_tile) * grid.TILE_SIZE, tile2Y(state.active_tile) * grid.TILE_SIZE, grid.TILE_SIZE, grid.TILE_SIZE, colors.C64_WHITE);

    render_tile_info();
}
