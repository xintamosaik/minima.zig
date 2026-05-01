pub const Weapon = enum(u8) {
    .sword,
    .club,
    .axe,

};
pub const Enemy = struct {
    weapon: Weapon,

};
