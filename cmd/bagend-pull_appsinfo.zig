const std = @import("std");

const url = "https://github.com/gcca/urmom/releases/download/clients/urmom-client-zig.tar.gz";

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = std.http.Client{
        .allocator = gpa,
        .io = io,
    };
    defer client.deinit();

    var compressed_writer: std.Io.Writer.Allocating = .init(gpa);
    defer compressed_writer.deinit();

    const fetch_result = try client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &compressed_writer.writer,
    });

    if (fetch_result.status != .ok) {
        std.debug.print("download failed: HTTP {d}\n", .{@intFromEnum(fetch_result.status)});
        return error.DownloadFailed;
    }

    const compressed = try compressed_writer.toOwnedSlice();
    defer gpa.free(compressed);

    var compressed_reader: std.Io.Reader = .fixed(compressed);
    var tar_writer: std.Io.Writer.Allocating = .init(gpa);
    defer tar_writer.deinit();

    var flate_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var gzip: std.compress.flate.Decompress = .init(&compressed_reader, .gzip, &flate_buffer);
    _ = gzip.reader.streamRemaining(&tar_writer.writer) catch |err| switch (err) {
        error.ReadFailed => return gzip.err orelse err,
        else => return err,
    };

    const tar_bytes = try tar_writer.toOwnedSlice();
    defer gpa.free(tar_bytes);

    var tar_reader: std.Io.Reader = .fixed(tar_bytes);
    var src_dir = try std.Io.Dir.cwd().openDir(io, "src", .{});
    defer src_dir.close(io);

    try std.tar.extract(io, src_dir, &tar_reader, .{
        .mode_mode = .ignore,
    });
}
