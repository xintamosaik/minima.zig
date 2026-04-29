pub const Scene = enum(u8) {
    intro,
    menu,
    new,
    load,
    exit,
};

pub var scene: Scene = .intro;
