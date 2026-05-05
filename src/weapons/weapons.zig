pub const Weapons = enum(u8) {
    sword,
    club,
    axe,
};

pub const Quality = enum(u8) { poor, fair, ok, good, great, exceptional };

pub const Damage = enum(u8) { blunt, slashing, piercing, missile };

pub const Kind = enum(u8) {
    sword,
    club,
    axe,
    bite,
    claws,
};

pub const Weapon = struct {
    kind: Kind,
    damage: Damage,
    quality: Quality,
};

pub const fangs = Weapon{
    .kind = .bite,
    .damage = .piercing,
    .quality = .poor,
};

pub const club = Weapon{
    .kind = .club,
    .damage = .blunt,
    .quality = .poor,
};
