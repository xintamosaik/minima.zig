const enemies = @import("../enemies/enemies.zig");

pub const Group = struct {
    enemy: enemies.Enemy,
    quantity: u8,
};

pub const Encounter = []const Group;
