//
// This needs to be synced with the "enum" on the browser TypeScript side!
//
// /src/scenes.mts
//
// Last synced 2026-05-15
//
pub const Scene = enum(u8) {
    intro,
    menu,
    credits,
    options,
    new,
    load,
    exit,
    battle_plain_wolves,
    battle_river_wolves,
    battle_plain_goblins,
};

pub var current: Scene = .intro;
pub var requested: ?Scene = null;

pub fn request(next: Scene) void {
    if (next == current) return;
    if (requested == next) return;
    requested = next;
}
