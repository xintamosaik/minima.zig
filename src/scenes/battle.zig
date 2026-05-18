extern "env" fn console_log(value: u32) void;

const scene = @import("../scene.zig");
const maps = @import("../maps/maps.zig");

const grid = @import("../grid.zig");

const heroes = @import("../heroes.zig");
const enemies = @import("../enemies/enemies.zig");

const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

fn tile2X(tile: u16) u32 {
    return @as(u32, tile) % maps.BATTLE_MAP_WIDTH;
}
fn tile2Y(tile: u16) u32 {
    return @as(u32, tile) / maps.BATTLE_MAP_WIDTH;
}

const BattleMode = enum {
    map,
    action_menu,
    move,
    attack,
};

//
//
//
//      :####:   ########    :##:    ########  ########
//     :######   ########     ##     ########  ########
//     ##:  :#      ##       ####       ##     ##
//     ##           ##       ####       ##     ##
//     ###:         ##      :#  #:      ##     ##
//     :#####:      ##       #::#       ##     #######
//      .#####:     ##      ##  ##      ##     #######
//         :###     ##      ######      ##     ##
//           ##     ##     .######.     ##     ##
//     #:.  :##     ##     :##  ##:     ##     ##
//     #######:     ##     ###  ###     ##     ########
//     .#####:      ##     ##:  :##     ##     ########
//
//
//
//
const EnemyInstance = struct { tile: u16, kind: enemies.Kind };

const Cursor = struct { now: u16, last_move: u8 };

/// This is a somewhat bad workaround marking "not spawned yet" or "outside of the map"
const NO_TILE: u16 = 0xffff;

const BattleState = struct {
    cursor: Cursor = .{ .now = 0, .last_move = 0 },
    rng: u32 = 0,
    enemy_instances: [16]EnemyInstance = undefined,
    enemy_instance_count: usize = 0,
    selected_tile: u16 = 0,
    hero_positions: [4]u16 = undefined,
    selected_hero: usize = 0,
    hero_active: bool = false,

    mode: BattleMode = .map,
    selected_menu_item: usize = 0,
    currentMoveRect: Rect = .{
        .x = 0,
        .y = 0,
        .w = 0,
        .h = 0,
    },
    reachable_tiles: [maps.BATTLE_MAP_LENGTH]bool = [_]bool{false} ** maps.BATTLE_MAP_LENGTH,
    pub fn reset(self: *BattleState) void {
        self.cursor = .{ .now = 0, .last_move = 0 };
        self.rng = 0;
        self.enemy_instance_count = 0;
        self.selected_tile = 0;

        for (&self.hero_positions) |*pos| {
            pos.* = NO_TILE;
        }

        self.selected_hero = 0;
        self.hero_active = false;

        self.selected_menu_item = 0;
        self.mode = .map;
        self.currentMoveRect = .{
            .x = 0,
            .y = 0,
            .w = 0,
            .h = 0,
        };
        self.reachable_tiles = [_]bool{false} ** maps.BATTLE_MAP_LENGTH;
    }
};

var state = BattleState{};

//
//
//
//      :####:   ######:     :##:   ##      ## ###   ##
//     :######   #######:     ##    ##.    .## ###   ##
//     ##:  :#   ##   :##    ####   ##:    :## ###:  ##
//     ##        ##    ##    ####    #: ## :#  ####  ##
//     ###:      ##   :##   :#  #:  :# .## ##: ##:#: ##
//     :#####:   #######:    #::#   :##.##.##: ## ## ##
//      .#####:  ######:    ##  ##  .##:##:##. ## ## ##
//         :###  ##         ######   ##    ##. ## :#:##
//           ##  ##        .######.  ###::###  ##  ####
//     #:.  :##  ##        :##  ##:  ###..###  ##  :###
//     #######:  ##        ###  ###  ###  ###  ##   ###
//     .#####:   ##        ##:  :##   ##  ###  ##   ###
//
//
//
//
const encounters = @import("../encounters/encounter.zig");

fn heroAt(tile: u16) bool {
    for (state.hero_positions) |pos| {
        if (pos != NO_TILE and pos == tile) return true;
    }
    return false;
}

fn enemyInstanceAt(tile: u16) bool {
    var i: usize = 0;
    while (i < state.enemy_instance_count) : (i += 1) {
        if (state.enemy_instances[i].tile == tile) return true;
    }
    return false;
}

fn trySpawnEnemyInstance(kind: enemies.Kind, tile: u16) bool {
    if (state.enemy_instance_count >= state.enemy_instances.len) return false;
    if (@as(u32, tile) >= maps.BATTLE_MAP_LENGTH) return false;

    if (enemyInstanceAt(tile)) return false;
    if (heroAt(tile)) return false;

    const tx = tile2X(tile);
    const ty = tile2Y(tile);

    if (!grid.isPassable(grid.getTile(tx, ty))) return false;

    state.enemy_instances[state.enemy_instance_count] = .{
        .tile = tile,
        .kind = kind,
    };
    state.enemy_instance_count += 1;

    return true;
}
fn rand() u32 {
    state.rng = state.rng *% 1664525 +% 1013904223;
    return state.rng;
}

fn randBelow(max: u32) u32 {
    return ((rand() >> 16) * max) >> 16;
}

pub fn spawnEncounter(encounter: encounters.Encounter, seed: u32) void {
    const HALF_WIDTH = maps.BATTLE_MAP_WIDTH / 2;
    state.rng = seed;

    for (encounter) |spawn| {
        var spawned: usize = 0;
        var attempts: usize = 0;

        const max_attempts = @as(usize, spawn.quantity) * 16;

        while (spawned < @as(usize, spawn.quantity) and
            attempts < max_attempts and
            state.enemy_instance_count < state.enemy_instances.len) : (attempts += 1)
        {
            const tx = HALF_WIDTH + randBelow(HALF_WIDTH);
            const ty = randBelow(maps.BATTLE_MAP_HEIGHT);
            const tile = ty * maps.BATTLE_MAP_WIDTH + tx;

            if (trySpawnEnemyInstance(spawn.kind, @intCast(tile))) {
                spawned += 1;
            }
        }
    }
}
fn trySpawnHero(hero_index: usize, tile: u16) bool {
    if (hero_index >= heroes.party.len) return false;
    if (@as(u32, tile) >= maps.BATTLE_MAP_LENGTH) return false;

    if (heroAt(tile)) return false;
    if (enemyInstanceAt(tile)) return false;

    const tx = tile2X(tile);
    const ty = tile2Y(tile);

    if (!grid.isPassable(grid.getTile(tx, ty))) return false;

    state.hero_positions[hero_index] = tile;

    return true;
}
fn spawnHeroes(seed: u32) void {
    const HALF_WIDTH = maps.BATTLE_MAP_WIDTH / 2;
    state.rng = seed;

    var hero_index: usize = 0;
    while (hero_index < heroes.party.len) : (hero_index += 1) {
        var attempts: usize = 0;
        const max_attempts: usize = 64;

        while (attempts < max_attempts) : (attempts += 1) {
            const tx = randBelow(HALF_WIDTH);
            const ty = randBelow(maps.BATTLE_MAP_HEIGHT);
            const tile = ty * maps.BATTLE_MAP_WIDTH + tx;

            if (trySpawnHero(hero_index, @intCast(tile))) {
                break;
            }
        }
    }
}

//
//
//
//      ######   ###   ##   ######   ########
//      ######   ###   ##   ######   ########
//        ##     ###:  ##     ##        ##
//        ##     ####  ##     ##        ##
//        ##     ##:#: ##     ##        ##
//        ##     ## ## ##     ##        ##
//        ##     ## ## ##     ##        ##
//        ##     ## :#:##     ##        ##
//        ##     ##  ####     ##        ##
//        ##     ##  :###     ##        ##
//      ######   ##   ###   ######      ##
//      ######   ##   ###   ######      ##
//
//
//
//

pub const EncounterConfig = struct {
    groups: encounters.Encounter,
    seed: u32,
};

pub const BattleDef = struct {
    tile_mapping: maps.TileMapping,
    pattern_map: maps.PatternMap,
    encounter_config: []const EncounterConfig,
    hero_seed: u32,
};

pub fn init(battle_def: BattleDef) void {
    maps.loadMap(battle_def.pattern_map, battle_def.tile_mapping);

    state.reset();

    spawnHeroes(battle_def.hero_seed);

    for (battle_def.encounter_config) |config| {
        spawnEncounter(config.groups, config.seed);
    }
}

//
//
//
//     ##    ##   ######
//     ##    ##   ######
//     ##    ##     ##
//     ##    ##     ##
//     ##    ##     ##
//     ##    ##     ##
//     ##    ##     ##
//     ##    ##     ##
//     ##    ##     ##
//     ##    ##     ##
//     :######:   ######
//      :####:    ######
//
//
//
//

fn heroIndexAt(tile: u16) ?usize {
    var i: usize = 0;
    while (i < heroes.party.len) : (i += 1) {
        if (state.hero_positions[i] != NO_TILE and state.hero_positions[i] == tile) {
            return i;
        }
    }

    return null;
}

fn selectHero(index: usize) void {
    state.selected_hero = index;
    state.selected_tile = state.hero_positions[index];
    state.hero_active = true;
    state.currentMoveRect = movementRectForHero(
        index,
        heroes.party[index].moveRadius,
    );
    computeReachableTiles(index, heroes.party[index].moveRadius);
}
fn clearHeroSelection() void {
    state.currentMoveRect = .{
        .x = 0,
        .y = 0,
        .w = 0,
        .h = 0,
    };
    state.selected_hero = 0;
    state.hero_active = false;
    state.reachable_tiles = [_]bool{false} ** maps.BATTLE_MAP_LENGTH;
}

fn tileIsBlockedForMovement(tile: u16, moving_hero_index: usize) bool {
    const tx = tile2X(tile);
    const ty = tile2Y(tile);
    if (!grid.isPassable(grid.getTile(tx, ty))) return true;

    var i: usize = 0;
    while (i < heroes.party.len) : (i += 1) {
        if (i != moving_hero_index and state.hero_positions[i] != NO_TILE and state.hero_positions[i] == tile) {
            return true;
        }
    }

    return enemyInstanceAt(tile);
}

fn computeReachableTiles(hero_index: usize, move_radius: u4) void {
    state.reachable_tiles = [_]bool{false} ** maps.BATTLE_MAP_LENGTH;

    const start = state.hero_positions[hero_index];
    if (start == NO_TILE) return;

    var cost: [maps.BATTLE_MAP_LENGTH]u16 = [_]u16{0xffff} ** maps.BATTLE_MAP_LENGTH;
    var queue: [maps.BATTLE_MAP_LENGTH]u16 = undefined;
    var head: usize = 0;
    var tail: usize = 0;

    cost[@as(usize, start)] = 0;
    state.reachable_tiles[@as(usize, start)] = true;
    queue[tail] = start;
    tail += 1;

    while (head < tail) : (head += 1) {
        const tile = queue[head];
        const tile_cost = cost[@as(usize, tile)];
        if (tile_cost >= move_radius) continue;

        const x = tile2X(tile);
        const y = tile2Y(tile);
        const next_cost = tile_cost + 1;
        const row_stride = @as(u16, @intCast(maps.BATTLE_MAP_WIDTH));
        const can_left = x > 0;
        const can_right = x + 1 < maps.BATTLE_MAP_WIDTH;
        const can_up = y > 0;
        const can_down = y + 1 < maps.BATTLE_MAP_HEIGHT;
        const neighbors = [_]u16{
            // orthogonal
            if (can_left) tile - 1 else NO_TILE,
            if (can_right) tile + 1 else NO_TILE,
            if (can_up) tile - row_stride else NO_TILE,
            if (can_down) tile + row_stride else NO_TILE,
            // diagonal (45°): still costs exactly one move step
            if (can_left and can_up) tile - row_stride - 1 else NO_TILE,
            if (can_right and can_up) tile - row_stride + 1 else NO_TILE,
            if (can_left and can_down) tile + row_stride - 1 else NO_TILE,
            if (can_right and can_down) tile + row_stride + 1 else NO_TILE,
        };

        for (neighbors) |neighbor| {
            if (neighbor == NO_TILE) continue;
            if (tileIsBlockedForMovement(neighbor, hero_index)) continue;
            if (next_cost >= cost[@as(usize, neighbor)]) continue;

            cost[@as(usize, neighbor)] = next_cost;
            state.reachable_tiles[@as(usize, neighbor)] = true;
            queue[tail] = neighbor;
            tail += 1;
        }
    }
}

//
//
//
//      ######   ###   ##  ######:   ##    ##  ########
//      ######   ###   ##  #######:  ##    ##  ########
//        ##     ###:  ##  ##   :##  ##    ##     ##
//        ##     ####  ##  ##    ##  ##    ##     ##
//        ##     ##:#: ##  ##   :##  ##    ##     ##
//        ##     ## ## ##  #######:  ##    ##     ##
//        ##     ## ## ##  ######:   ##    ##     ##
//        ##     ## :#:##  ##        ##    ##     ##
//        ##     ##  ####  ##        ##    ##     ##
//        ##     ##  :###  ##        ##    ##     ##
//      ######   ##   ###  ##        :######:     ##
//      ######   ##   ###  ##         :####:      ##
//
//
//
//
const input = @import("../input.zig");

const CURSOR_SLOW_DOWN = 8;

var last_input: input.Layout = .{
    .buttons_lo = 0,
    .buttons_hi = 0,
    ._reserved = 0,
    .mouse_x = 0,
    .mouse_y = 0,
    .mouse_buttons = 0,
};

fn cycle_heroes(input_data: input.Layout) void {
    const last_hero = heroes.party.len - 1;
    if ((input_data.buttons_hi & input.BTN_L) != 0 and (last_input.buttons_hi & input.BTN_L) == 0) {
        if (state.selected_hero > 0) {
            state.selected_hero -= 1;
        } else {
            state.selected_hero = last_hero;
        }
        selectHero(state.selected_hero);
    }
    if ((input_data.buttons_hi & input.BTN_R) != 0 and (last_input.buttons_hi & input.BTN_R) == 0) {
        if (state.selected_hero < last_hero) {
            state.selected_hero += 1;
        } else {
            state.selected_hero = 0;
        }
        selectHero(state.selected_hero);
    }
}
fn input_battle_map(input_data: input.Layout) void {
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
    if ((input_data.buttons_lo & input.BTN_UP) != 0 and
        state.cursor.now > maps.BATTLE_MAP_WIDTH - 1 and
        (state.cursor.last_move > CURSOR_SLOW_DOWN or
            (last_input.buttons_lo & input.BTN_UP) == 0))
    {
        state.cursor.now -= maps.BATTLE_MAP_WIDTH;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_DOWN) != 0 and
        state.cursor.now < maps.BATTLE_MAP_LENGTH - maps.BATTLE_MAP_WIDTH and
        (state.cursor.last_move > CURSOR_SLOW_DOWN or
            (last_input.buttons_lo & input.BTN_DOWN) == 0))
    {
        state.cursor.now += maps.BATTLE_MAP_WIDTH;
        state.cursor.last_move = 0;
    }
    if ((input_data.buttons_lo & input.BTN_A) != 0 and (last_input.buttons_lo & input.BTN_A) == 0) {
        state.selected_tile = state.cursor.now;
        if (heroIndexAt(state.selected_tile)) |index| {
            selectHero(index);
        }
    }
    if ((input_data.buttons_lo & input.BTN_B) != 0 and (last_input.buttons_lo & input.BTN_B) == 0) {
        clearHeroSelection();
    }
    if ((input_data.buttons_lo & input.BTN_X) != 0 and (last_input.buttons_lo & input.BTN_X) == 0 and state.hero_active) {
        state.mode = .action_menu;
    }
    cycle_heroes(input_data);
}

fn input_action_menu(input_data: input.Layout) void {
    if ((input_data.buttons_lo & input.BTN_B) != 0 and (last_input.buttons_lo & input.BTN_B) == 0) {
        state.mode = .map;
    }
    if ((input_data.buttons_lo & input.BTN_UP) != 0 and (last_input.buttons_lo & input.BTN_UP) == 0 and state.selected_menu_item > 0) {
        state.selected_menu_item -= 1;
    }

    if ((input_data.buttons_lo & input.BTN_DOWN) != 0 and (last_input.buttons_lo & input.BTN_DOWN) == 0 and state.selected_menu_item < action_menu_items.len - 1) {
        state.selected_menu_item += 1;
    }
    cycle_heroes(input_data);
}
fn input_cursor(input_data: input.Layout) void {
    state.cursor.last_move +%= 1;
    switch (state.mode) {
        .map => input_battle_map(input_data),
        .action_menu => input_action_menu(input_data),
        .move => {},
        .attack => {},
    }

    // if ((input_data.buttons_lo & input.BTN_Y) != 0) {}
    if ((input_data.buttons_hi & input.BTN_SELECT) != 0) {
        scene.request(.menu);
    }

    // We need to retain what was input before to make the logic work
    last_input = input_data;
}

//
//
//
//     ########   ######     :####:  ##   ###
//     ########   ######     ######  ##   ##
//        ##        ##     :##:  .#  ## :##:
//        ##        ##     ##        ##.##:
//        ##        ##     ##.       #####
//        ##        ##     ##        #####
//        ##        ##     ##        #####:
//        ##        ##     ##.       ##::##
//        ##        ##     ##        ##  ##
//        ##        ##     :##:  .#  ##  :##
//        ##      ######     ######  ##   ##
//        ##      ######     :####:  ##   :##
//
//
//
//

pub fn tick(input_data: input.Layout) void {
    input_cursor(input_data);
}

//
//
//
//     ######:   ########  ###   ##  #####:    ########  ######:
//     #######   ########  ###   ##  #######   ########  #######
//     ##   :##  ##        ###:  ##  ##  :##:  ##        ##   :##
//     ##    ##  ##        ####  ##  ##   :##  ##        ##    ##
//     ##   :##  ##        ##:#: ##  ##   .##  ##        ##   :##
//     #######:  #######   ## ## ##  ##    ##  #######   #######:
//     ######    #######   ## ## ##  ##    ##  #######   ######
//     ##   ##.  ##        ## :#:##  ##   .##  ##        ##   ##.
//     ##   ##   ##        ##  ####  ##   :##  ##        ##   ##
//     ##   :##  ##        ##  :###  ##  :##:  ##        ##   :##
//     ##    ##: ########  ##   ###  #######   ########  ##    ##:
//     ##    ### ########  ##   ###  #####:    ########  ##    ###
//
//
//
//

const renderer = @import("../render.zig");

const ui = @import("../ui.zig");
const font = @import("../font.zig");
const colors = @import("../colors.zig");

const patterns_outside = @import("../patterns/outside.zig");
const patterns_general = @import("../patterns/general.zig");

const BG = colors.C64_BLACK;
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

const HERO_COLOR = colors.C64_LIGHT_GRAY;
const HERO_ACTIVE_COLOR = colors.C64_YELLOW;

fn render_hero(index: usize, label: u8) void {
    const color = if (index == state.selected_hero and state.hero_active == true) HERO_ACTIVE_COLOR else HERO_COLOR;

    font.drawMono(
        tile2X(state.hero_positions[index]) * grid.TILE_SIZE,
        tile2Y(state.hero_positions[index]) * grid.TILE_SIZE,
        label,
        color,
    );
}
fn enemyNameAt(tile: u16) []const u8 {
    var i: usize = 0;
    while (i < state.enemy_instance_count) : (i += 1) {
        const enemy_instance = state.enemy_instances[i];

        if (enemy_instance.tile != tile) continue;

        return switch (enemy_instance.kind) {
            .wolf => "WOLF",
            .goblin => "GOBLIN",
        };
    }

    return "";
}
fn render_enemy_instances() void {
    var i: usize = 0;
    while (i < state.enemy_instance_count) : (i += 1) {
        const enemy_instance = state.enemy_instances[i];
        const enemy = enemies.get(enemy_instance.kind);
        renderer.drawBitmap8x8Mono(
            tile2X(enemy_instance.tile) * grid.TILE_SIZE,
            tile2Y(enemy_instance.tile) * grid.TILE_SIZE,
            enemy.pattern,
            enemy.color,
        );
    }
}
fn selectedTileKind() grid.TileKind {
    return grid.getTile(tile2X(state.selected_tile), tile2Y(state.selected_tile));
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
    const currentTile = selectedTileKind();
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

    const hero_name = heroNameAt(state.selected_tile);
    const enemy_name = enemyNameAt(state.selected_tile);

    const occupant_type: []const u8 =
        if (hero_name.len > 0)
            "hero"
        else if (enemy_name.len > 0)
            "enemy"
        else
            "";

    const occupant_name: []const u8 =
        if (hero_name.len > 0)
            hero_name
        else
            enemy_name;

    font.drawString(
        32 * grid.TILE_SIZE,
        2 * grid.TILE_SIZE,
        occupant_type,
        colors.C64_LIGHT_GRAY,
        colors.C64_BLACK,
    );

    font.drawString(
        32 * grid.TILE_SIZE,
        3 * grid.TILE_SIZE,
        occupant_name,
        colors.C64_YELLOW,
        colors.C64_BLACK,
    );
    if (state.hero_active) {
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
            '0' + @as(u8, heroes.party[state.selected_hero].moveRadius),
            colors.C64_YELLOW,
        );
    }
}

fn movementRectForHero(hero: usize, radius: u4) Rect {
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
fn render_heroes() void {
    var i: usize = 0;
    while (i < heroes.party.len) : (i += 1) {
        render_hero(i, '1' + @as(u8, @intCast(i)));
    }
}

const ActionMenuItem = struct {
    label: []const u8,
    y: u32,
    color: u32,
};
const action_menu_items = [_]ActionMenuItem{
    .{ .label = "move", .y = 8 * 3, .color = colors.C64_GREEN },
    .{ .label = "attack", .y = 8 * 7, .color = colors.C64_RED },
    .{ .label = "cast spell", .y = 8 * 11, .color = colors.C64_PURPLE },
    .{ .label = "use item", .y = 8 * 15, .color = colors.C64_BLUE },
    .{ .label = "special", .y = 8 * 19, .color = colors.C64_BROWN },
};

const ACTION_MENU_MARGIN_LEFT = 8 * 3;
const ACTION_MENU_WIDTH: u32 = 8 * 26;
const ACTION_MENU_HEIGHT: u32 = 24;

fn drawActionMenuItem(y: u32, label: []const u8, fg: u32, bg: u32) void {
    renderer.fillRect(ACTION_MENU_MARGIN_LEFT, y, ACTION_MENU_WIDTH, ACTION_MENU_HEIGHT, bg);
    font.drawString(32, y + 8, label, fg, bg);
}
const action_menu_rect: Rect = .{ .x = grid.TILE_SIZE * 2, .y = grid.TILE_SIZE * 2, .w = grid.TILE_SIZE * maps.BATTLE_MAP_WIDTH - 32, .h = grid.TILE_SIZE * maps.BATTLE_MAP_HEIGHT - 32 };

fn render_action_menu() void {
    renderer.fillRect(action_menu_rect.x, action_menu_rect.y, action_menu_rect.w, action_menu_rect.h, colors.C64_BLACK);
    renderer.drawRectOutline(action_menu_rect.x, action_menu_rect.y, action_menu_rect.w, action_menu_rect.h, colors.C64_DARK_GRAY);

    for (action_menu_items) |item| {
        drawActionMenuItem(item.y, item.label, BG, item.color);
    }

    const item = action_menu_items[state.selected_menu_item];

    renderer.drawRectOutline(
        ACTION_MENU_MARGIN_LEFT,
        item.y,
        ACTION_MENU_WIDTH,
        ACTION_MENU_HEIGHT,
        colors.C64_WHITE,
    );
}
fn render_map() void {
    render_tiles();
    if (state.hero_active) {
        var tile: usize = 0;
        while (tile < maps.BATTLE_MAP_LENGTH) : (tile += 1) {
            if (!state.reachable_tiles[tile]) continue;

            const tx = @as(u32, @intCast(tile % maps.BATTLE_MAP_WIDTH));
            const ty = @as(u32, @intCast(tile / maps.BATTLE_MAP_WIDTH));
            const px = tx * grid.TILE_SIZE;
            const py = ty * grid.TILE_SIZE;

            var row: u32 = 1;
            while (row < grid.TILE_SIZE - 1) : (row += 1) {
                // 45° diagonal stripe family: x grows with y.
                var col: u32 = 1;
                while (col < grid.TILE_SIZE - 1) : (col += 1) {
                    if (((col + grid.TILE_SIZE - row) % 3) == 0) {
                        renderer.fillRect(px + col, py + row, 1, 1, colors.C64_LIGHT_GREEN);
                    }
                }
            }
        }
    }
    renderer.drawRectOutline(
        state.currentMoveRect.x,
        state.currentMoveRect.y,
        state.currentMoveRect.w,
        state.currentMoveRect.h,
        colors.C64_CYAN,
    );

    font.drawString(0 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, "ENEMIES", colors.C64_CYAN, colors.C64_BLACK);
    font.drawString(9 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, &ui.u999ToChars(@intCast(state.enemy_instance_count)), colors.C64_CYAN, colors.C64_BLACK);

    const position = ui.u999ToChars(state.selected_tile);
    font.drawString(32 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 2) * grid.TILE_SIZE, "POS", colors.C64_LIGHT_BLUE, colors.C64_BLACK);
    font.drawString(37 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 2) * grid.TILE_SIZE, &position, colors.C64_LIGHT_BLUE, colors.C64_BLACK);

    const activeX = ui.u999ToChars(tile2X(state.selected_tile));
    font.drawString(32 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 1) * grid.TILE_SIZE, "X", colors.C64_LIGHT_RED, colors.C64_BLACK);
    font.drawString(37 * grid.TILE_SIZE, (maps.BATTLE_MAP_HEIGHT - 1) * grid.TILE_SIZE, &activeX, colors.C64_LIGHT_RED, colors.C64_BLACK);

    const activeY = ui.u999ToChars(tile2Y(state.selected_tile));
    font.drawString(32 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, "Y", colors.C64_LIGHT_GREEN, colors.C64_BLACK);
    font.drawString(37 * grid.TILE_SIZE, maps.BATTLE_MAP_HEIGHT * grid.TILE_SIZE, &activeY, colors.C64_LIGHT_GREEN, colors.C64_BLACK);

    render_enemy_instances();

    render_heroes();

    renderer.drawRectOutline(0, 0, grid.TILE_SIZE * maps.BATTLE_MAP_WIDTH, grid.TILE_SIZE * maps.BATTLE_MAP_HEIGHT, colors.C64_DARK_GRAY);
    renderer.drawRectOutline(tile2X(state.cursor.now) * grid.TILE_SIZE, tile2Y(state.cursor.now) * grid.TILE_SIZE, grid.TILE_SIZE, grid.TILE_SIZE, colors.C64_YELLOW);
    renderer.drawRectOutline(tile2X(state.selected_tile) * grid.TILE_SIZE, tile2Y(state.selected_tile) * grid.TILE_SIZE, grid.TILE_SIZE, grid.TILE_SIZE, colors.C64_WHITE);

    render_tile_info();
}

fn render_mode_map() void {
    render_map();
}
fn render_mode_action_menu() void {
    render_map();
    render_action_menu();
}
fn render_mode_move() void {
    render_map();
}

fn render_mode_attack() void {
    render_map();
}
pub fn render() void {
    ui.clearScreen(BG);
    switch (state.mode) {
        .map => render_mode_map(),
        .action_menu => render_mode_action_menu(),
        .move => render_mode_move(),
        .attack => render_mode_attack(),
    }
}
