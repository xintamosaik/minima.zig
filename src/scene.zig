pub const Scene = enum(u8) {
    last,
    intro,
    menu,
    credits,
    options,
    new,
    load,
    exit,
};

pub var scene: Scene = .intro;
