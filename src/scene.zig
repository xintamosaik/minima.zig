pub const Scene = enum(u8) {
    last,
    intro,
    menu,
    credits,
    options,
    new,
    load,
    exit,
    battle_plain_wolves,
    battle_plain_goblins,
};

pub var scene: Scene = .intro;
