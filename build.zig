const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "LudoDB",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    @import("system_sdk").addLibraryPathsTo(exe);

    @import("zgpu").addLibraryPathsTo(exe);

    const zgui = b.dependency("zgui", .{
        .shared = false,
        .with_implot = true,
        .target = target,
        .backend = .glfw_wgpu,
    });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));

    { // Needed for glfw/wgpu rendering backend
        const zglfw = b.dependency("zglfw", .{});
        exe.root_module.addImport("zglfw", zglfw.module("root"));
        exe.linkLibrary(zglfw.artifact("glfw"));

        const zpool = b.dependency("zpool", .{});
        exe.root_module.addImport("zpool", zpool.module("root"));

        const zgpu = b.dependency("zgpu", .{});
        exe.root_module.addImport("zgpu", zgpu.module("root"));
        exe.linkLibrary(zgpu.artifact("zdawn"));
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //
    // Fast "check" build
    // https://kristoff.it/blog/improving-your-zls-experience/
    const exe_check = b.addExecutable(.{
        .name = "LudoDB",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    @import("system_sdk").addLibraryPathsTo(exe_check);

    @import("zgpu").addLibraryPathsTo(exe_check);

    exe_check.root_module.addImport("zgui", zgui.module("root"));
    exe_check.linkLibrary(zgui.artifact("imgui"));

    {
        const zglfw = b.dependency("zglfw", .{});
        exe_check.root_module.addImport("zglfw", zglfw.module("root"));
        exe_check.linkLibrary(zglfw.artifact("glfw"));

        const zpool = b.dependency("zpool", .{});
        exe_check.root_module.addImport("zpool", zpool.module("root"));

        const zgpu = b.dependency("zgpu", .{});
        exe_check.root_module.addImport("zgpu", zgpu.module("root"));
        exe_check.linkLibrary(zgpu.artifact("zdawn"));
    }

    const check = b.step("check", "Check if ludodb compiles");
    check.dependOn(&exe_check.step);
}
