const encounters = @import("encounter.zig");

pub const encounter: encounters.Encounter = &.{
    .{
        .kind = .wolf,
        .quantity = 7,
    },
};
