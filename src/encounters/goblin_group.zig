const encounter = @import("encounter.zig");
const enemies = @import("../enemies/enemies.zig");

pub const spawn: encounter.Encounter = &.{
    .{
        .enemy = enemies.goblin,
        .quantity = 5,
    },
};
