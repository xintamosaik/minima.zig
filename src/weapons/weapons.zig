pub const Weapons = enum(u8) {
    sword,
    club,
    axe,
};

pub const Quality = enum(u8) {
    poor,
    fair,
    ok,
    good,
    great,
    exceptional
};

pub const Damage = enum(u8) {
    blunt,
    slashing,
    piercing,
    missile
};

pub const Weapon = struct {
    damage: Damage,
    quality: Quality,
};
