const wolfpack = @import("../encounters/pack_of_wolves.zig");
const goblingroup = @import("../encounters/goblin_group.zig");
const maps = @import("../maps/maps.zig");
const plain = @import("../maps/battle/plain.zig");
var rng_state: u32 = 0x12345678;

const tile_mapping = maps.TileMapping{
    .base = .empty,
    .a = .dirt,
    .b = .water,
};

pub fn init() void {
    maps.loadMap(.{
        .a = plain.A,
        .b = plain.B,
    }, tile_mapping);
    // spawnEncounter(wolfpack.spawn, 0x12345678);
    // spawnEncounter(goblingroup.spawn, 0x87654321);
}
