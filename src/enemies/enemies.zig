const weapons = @import("../weapons/weapons.zig");
pub const enemies = enum (u8) {
    wolf,
    goblin,
};
pub const Enemy = struct {
    weapon: weapons.Weapon,
};

