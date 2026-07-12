const std = @import("std");

inline fn buildHttplib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const httplib = b.addModule("httplib", .{
        .root_source_file = b.path("src/httplib.zig"),
        .target = target,
        .optimize = optimize,
    });

    httplib.addIncludePath(b.path("3rdparty"));
    httplib.addIncludePath(b.path("src"));
    httplib.addCSourceFile(.{
        .file = b.path("src/httplibshim.cpp"),
        .flags = &.{"-std=c++23"},
        .language = .cpp,
    });
    httplib.link_libcpp = true;

    return httplib;
}

inline fn buildMustache(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const mustache = b.addModule("mustache", .{
        .root_source_file = b.path("src/mustache.zig"),
        .target = target,
        .optimize = optimize,
    });

    mustache.addIncludePath(b.path("3rdparty"));
    mustache.addIncludePath(b.path("src"));
    mustache.addCSourceFile(.{
        .file = b.path("src/mustacheshim.cpp"),
        .flags = &.{"-std=c++23"},
        .language = .cpp,
    });
    mustache.link_libcpp = true;

    return mustache;
}

inline fn buildSqlite3(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const sqlite3 = b.addModule("sqlite3", .{
        .root_source_file = b.path("src/sqlite3.zig"),
        .target = target,
        .optimize = optimize,
    });

    sqlite3.link_libc = true;
    sqlite3.linkSystemLibrary("sqlite3", .{});

    return sqlite3;
}

inline fn buildBagEnd(b: *std.Build, target: std.Build.ResolvedTarget, httplib: *std.Build.Module, mustache: *std.Build.Module, sqlite3: *std.Build.Module) *std.Build.Module {
    const bagend = b.addModule("bagend", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "httplib", .module = httplib },
            .{ .name = "mustache", .module = mustache },
            .{ .name = "sqlite3", .module = sqlite3 },
        },
    });

    return bagend;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const httplib = buildHttplib(b, target, optimize);
    const mustache = buildMustache(b, target, optimize);
    const sqlite3 = buildSqlite3(b, target, optimize);
    const bagend = buildBagEnd(b, target, httplib, mustache, sqlite3);

    const exe = b.addExecutable(.{
        .name = "bagend",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bagend", .module = bagend },
                .{ .name = "httplib", .module = httplib },
                .{ .name = "sqlite3", .module = sqlite3 },
            },
        }),
    });

    b.installArtifact(exe);

    const check_step = b.step("check", "Check if it compiles");
    check_step.dependOn(&exe.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = bagend,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const mustache_tests = b.addTest(.{
        .root_module = mustache,
    });

    const run_mustache_tests = b.addRunArtifact(mustache_tests);

    const sqlite3_tests = b.addTest(.{
        .root_module = sqlite3,
    });

    const run_sqlite3_tests = b.addRunArtifact(sqlite3_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_mustache_tests.step);
    test_step.dependOn(&run_sqlite3_tests.step);
}
