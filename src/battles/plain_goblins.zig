const maps = @import("../maps/maps.zig");
const plain = @import("../maps/battle/plain.zig");
const encounters = @import("../encounters/encounter.zig");
 
const goblingroup = @import("../encounters/goblin_group.zig");

const input = @import("../input.zig");
const battle = @import("../scenes/battle.zig");

pub const tile_mapping = maps.TileMapping{
    .base = .empty,
    .a = .dirt,
    .b = .water,
};

pub const map = maps.PatternMap{
    .a = plain.A,
    .b = plain.B,
};

pub const encounter_config: [1]battle.EncounterConfig = .{
    .{ .spawn = goblingroup.spawn, .seed = 0x87654321 },
};

const battle_def: battle.BattleDef = .{
    .tile_mapping = tile_mapping,
    .pattern_map = map,
    .encounter_config = &encounter_config,
};
var loaded = false;

pub fn tick(input_data: input.Layout) void {
    if (!loaded) {
        battle.init(battle_def);
        loaded = true;
    }

    battle.tick(input_data);
}

pub fn render() void {
    battle.render();
}
