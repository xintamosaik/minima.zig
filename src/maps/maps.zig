const grid = @import("../grid.zig");

pub const PatternMap = struct {
    a: [24]u32,
    b: [24]u32,
};

pub const TileMapping = struct {
    base: grid.TileKind,
    a: grid.TileKind,
    b: grid.TileKind,
};

fn bitAt(rows: [24]u32, x: u32, y: u32) bool {
    const row = rows[y];
    const shift: u5 = @intCast(31 - x);
    return ((row >> shift) & 1) != 0;
}

pub fn loadMap(map: PatternMap, mapping: TileMapping) void {
    var y: u32 = 0;
    while (y < 24) : (y += 1) {
        var x: u32 = 0;
        while (x < 32) : (x += 1) {
            const kind =
                if (bitAt(map.b, x, y)) mapping.b else if (bitAt(map.a, x, y)) mapping.a else mapping.base;

            grid.setTile(x, y, kind);
        }
    }
}
