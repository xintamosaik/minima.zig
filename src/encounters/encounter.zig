const enemies = @import("../enemies/enemies.zig");

pub const Group = struct {
    kind: enemies.Kind,
    quantity: u8,
};

pub const Encounter = []const Group;
