const enemies = @import("../enemies/enemies.zig");

pub const Group = struct {
    kind: enemies.Enemies,
    quantity: u8,
};

pub const Encounter = []const Group;
