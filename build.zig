const std = @import("std");

fn cppFlags(comptime standard: []const u8, target: std.Build.ResolvedTarget) []const []const u8 {
    _ = target;
    return &.{standard};
}

fn cppFlagsNoDeprecatedErrors(comptime standard: []const u8, target: std.Build.ResolvedTarget) []const []const u8 {
    _ = target;
    return &.{ standard, "-Wno-error=deprecated-declarations", "-Wno-deprecated-declarations" };
}

fn linkCpp(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    _ = target;
    module.link_libcpp = true;
}

fn linuxLibstdcxxPath() []const u8 {
    return "/usr/lib/libstdc++.so.6";
}

fn addGrpcShim(b: *std.Build, grpc: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (target.result.os.tag == .linux) {
        const compile = b.addSystemCommand(&.{
            "sh",
            "-c",
            "g++ -std=c++20 -Wno-error=deprecated-declarations -Wno-deprecated-declarations $(pkg-config --cflags grpc++) -I src -c src/grpcshim.cpp -o \"$1\"",
            "compile-grpcshim",
        });
        compile.addFileInput(b.path("src/grpcshim.cpp"));
        compile.addFileInput(b.path("src/grpcshim.hpp"));

        grpc.addObjectFile(compile.addOutputFileArg("grpcshim.o"));
        grpc.addObjectFile(.{ .cwd_relative = linuxLibstdcxxPath() });
    } else {
        grpc.addCSourceFile(.{
            .file = b.path("src/grpcshim.cpp"),
            .flags = cppFlagsNoDeprecatedErrors("-std=c++20", target),
            .language = .cpp,
        });
        linkCpp(grpc, target);
    }
}

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
        .flags = cppFlags("-std=c++23", target),
        .language = .cpp,
    });
    linkCpp(httplib, target);

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
        .flags = cppFlags("-std=c++23", target),
        .language = .cpp,
    });
    linkCpp(mustache, target);

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

inline fn buildGrpc(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const grpc = b.addModule("grpc", .{
        .root_source_file = b.path("src/grpc.zig"),
        .target = target,
        .optimize = optimize,
    });

    grpc.addIncludePath(b.path("src"));
    addGrpcShim(b, grpc, target);
    grpc.linkSystemLibrary("grpc++", .{ .use_pkg_config = .force });

    return grpc;
}

inline fn buildBagEnd(b: *std.Build, target: std.Build.ResolvedTarget, httplib: *std.Build.Module, mustache: *std.Build.Module, sqlite3: *std.Build.Module, protobuf: *std.Build.Module, grpc: *std.Build.Module) *std.Build.Module {
    const bagend = b.addModule("bagend", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "httplib", .module = httplib },
            .{ .name = "mustache", .module = mustache },
            .{ .name = "sqlite3", .module = sqlite3 },
            .{ .name = "protobuf", .module = protobuf },
            .{ .name = "grpc", .module = grpc },
        },
    });

    return bagend;
}

inline fn buildProtobuf(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });

    return protobuf_dep.module("protobuf");
}

inline fn installArtifacts(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const pull_appsinfo = b.addExecutable(.{
        .name = "bagend-pull_appsinfo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cmd/bagend-pull_appsinfo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(pull_appsinfo);

    const pull_appsinfo_step = b.step("pull_appsinfo", "Run bagend-pull_appsinfo");

    const pull_appsinfo_cmd = b.addRunArtifact(pull_appsinfo);
    pull_appsinfo_step.dependOn(&pull_appsinfo_cmd.step);

    if (b.args) |args| {
        pull_appsinfo_cmd.addArgs(args);
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const httplib = buildHttplib(b, target, optimize);
    const mustache = buildMustache(b, target, optimize);
    const sqlite3 = buildSqlite3(b, target, optimize);
    const protobuf = buildProtobuf(b, target, optimize);
    const grpc = buildGrpc(b, target, optimize);
    const bagend = buildBagEnd(b, target, httplib, mustache, sqlite3, protobuf, grpc);

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
                .{ .name = "protobuf", .module = protobuf },
            },
        }),
    });

    b.installArtifact(exe);
    installArtifacts(b, target, optimize);

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
