const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // RMPP target features
    var cpu_features: std.Target.Cpu.Feature.Set = std.Target.aarch64.cpu.cortex_a53.features;
    cpu_features.addFeature(@intFromEnum(std.Target.aarch64.Feature.aes));
    cpu_features.addFeature(@intFromEnum(std.Target.aarch64.Feature.crc));
    cpu_features.addFeature(@intFromEnum(std.Target.aarch64.Feature.fp_armv8));
    cpu_features.addFeature(@intFromEnum(std.Target.aarch64.Feature.neon));
    cpu_features.addFeature(@intFromEnum(std.Target.aarch64.Feature.sha2));

    const rmpp_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.cortex_a53 },
        .cpu_features_add = cpu_features,
        .os_tag = .linux,
        .abi = .gnu,
    });

    const mod = b.addModule("zqtfb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
    });

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = rmpp_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zqtfb", .module = mod },
            },
        }),
    });

    b.installArtifact(example);

    // const mod_tests = b.addTest(.{
    //     .root_module = mod,
    // });

    // const run_mod_tests = b.addRunArtifact(mod_tests);

    // const example_tests = b.addTest(.{
    //     .root_module = example.root_module,
    // });

    // const run_example_tests = b.addRunArtifact(example_tests);

    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_example_tests.step);
}
