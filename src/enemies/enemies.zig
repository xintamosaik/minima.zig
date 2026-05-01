const weapons = @import("../weapons/weapons.zig");
pub const Enemies = enum (u8) {
    wolf,
    goblin,
};

pub const Enemy = struct {
    kind: Enemies,
    weapon: weapons.Weapon,
};

pub const wolf = Enemy{
    .kind = .wolf,
    .weapon = weapons.wolf_bite,
};

pub const goblin = Enemy{
    .kind = .goblin,
    .weapon = weapons.club,
};
