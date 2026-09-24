const std = @import("std");

const remarkable = @import("zig_remarkable");

pub fn build(b: *std.Build) void {
    const device = b.option(remarkable.Device, "device", "reMarkable device to build for") orelse .ferrari;
    const optimize = b.standardOptimizeOption(.{});

    const target = remarkable.resolve(b, device);

    const mod = b.addModule("zqtfb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
    });

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zqtfb", .module = mod },
            },
        }),
    });

    b.installArtifact(example);
}
