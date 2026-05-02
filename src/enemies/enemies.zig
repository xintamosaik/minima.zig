const weapons = @import("../weapons/weapons.zig");
const pattern = @import("../patterns/patterns.zig");
const pattern_enemies = @import("../patterns/enemy.zig");
pub const Enemies = enum (u8) {
    wolf,
    goblin,
};

pub const Enemy = struct {
    kind: Enemies,
    weapon: weapons.Weapon,
    pattern: pattern.Pattern,
};

pub const wolf = Enemy{
    .kind = .wolf,
    .weapon = weapons.fangs,
    .pattern = pattern_enemies.WOLF,
};

pub const goblin = Enemy{
    .kind = .goblin,
    .weapon = weapons.club,
    .pattern = pattern_enemies.GOBLIN
};
