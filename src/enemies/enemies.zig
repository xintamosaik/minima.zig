const weapons = @import("../weapons/weapons.zig");
const pattern = @import("../patterns/patterns.zig");
const pattern_enemies = @import("../patterns/enemy.zig");
const colors = @import("../colors.zig");
pub const Kind = enum(u8) {
    wolf,
    goblin,
};

pub const Enemy = struct {
    color: u32,
    kind: Kind,
    weapon: weapons.Weapon,
    pattern: pattern.Pattern,
};

pub const wolf = Enemy{
    .color = colors.C64_DARK_GRAY,
    .kind = .wolf,
    .weapon = weapons.fangs,
    .pattern = pattern_enemies.WOLF,
};

pub const goblin = Enemy{ .color = colors.C64_GREEN, .kind = .goblin, .weapon = weapons.club, .pattern = pattern_enemies.GOBLIN };
pub fn get(kind: Kind) Enemy {
    return switch (kind) {
        .wolf => wolf,
        .goblin => goblin,
    };
}
