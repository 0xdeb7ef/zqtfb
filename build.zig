const std = @import("std");

pub const remarkable = @import("zig_remarkable");

const Manifest = .{
    .name = "ZQTFB Example",
    .application = "example",
    .qtfb = true,
};

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

    const install = b.addInstallArtifact(example, .{
        .dest_dir = .{
            .override = .{
                .custom = Manifest.application,
            },
        },
    });

    const json = std.fmt.allocPrint(
        b.allocator,
        "{f}\n",
        .{std.json.fmt(
            Manifest,
            .{ .whitespace = .indent_2 },
        )},
    ) catch unreachable;

    const manifest = b.addInstallFileWithDir(
        b.addWriteFiles().add("manifest", json),
        install.dest_dir.?,
        "external.manifest.json",
    );

    b.getInstallStep().dependOn(&install.step);
    b.getInstallStep().dependOn(&manifest.step);
}
