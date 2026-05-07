const encounters = @import("encounter.zig");

pub const encounter: encounters.Encounter = &.{
    .{
        .kind = .goblin,
        .quantity = 5,
    },
};
