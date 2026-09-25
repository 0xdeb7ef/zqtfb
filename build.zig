const std = @import("std");

const remarkable = @import("zig_remarkable");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const device = b.option(
        remarkable.Device,
        "device",
        "reMarkable device to build the example for (default: ferrari)",
    ) orelse .ferrari;

    const mod = b.addModule("zqtfb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
        .optimize = optimize,
    });

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = remarkable.resolve(b, device),
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zqtfb", .module = mod },
            },
        }),
    });

    b.installArtifact(example);
}
