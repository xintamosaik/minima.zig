const encounters = @import("encounter.zig");
const enemies = @import("../enemies/enemies.zig");

pub const encounter: encounters.Encounter = &.{
    .{
        .kind = .wolf,
        .quantity = 7,
    },
};
