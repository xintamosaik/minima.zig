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

pub var current: Scene = .intro;
pub var requested: ?Scene = null;

pub fn request(next: Scene) void {
    requested = next;
}
