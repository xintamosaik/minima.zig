pub const Hero = struct {
    name: []const u8,
    moveRadius: u4 = 1,
};

pub var party: [4]Hero = .{
    .{ .name = "tank" },
    .{ .name = "healer", .moveRadius = 2 },
    .{ .name = "dd", .moveRadius = 3 },
    .{ .name = "control", .moveRadius = 2 },
};
