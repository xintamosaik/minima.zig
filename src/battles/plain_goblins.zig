const maps = @import("../maps/maps.zig");
const plain = @import("../maps/patterns.zig");
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
    .a = plain.VEGETATION,
    .b = plain.LAKE,
};

pub const encounter_config: [1]battle.EncounterConfig = .{
    .{ .groups = goblingroup.encounter, .seed = 0x87654321 },
};

const battle_def: battle.BattleDef = .{
    .tile_mapping = tile_mapping,
    .pattern_map = map,
    .encounter_config = &encounter_config,
};

pub fn enter() void {
    battle.init(battle_def);
}

pub fn tick(input_data: input.Layout) void {
    battle.tick(input_data);
}

pub fn render() void {
    battle.render();
}
