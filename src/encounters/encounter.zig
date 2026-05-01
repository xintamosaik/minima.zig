const enemy = @import("../enemies/enemies.zig");

pub const Group = struct {
    enemy: enemy.Enemy,
    quantity: u8,
};

pub const Encounter = []Group;
