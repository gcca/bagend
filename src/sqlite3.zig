const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const OpenError = error{
    OpenFailed,
};

pub const Sqlite3 = struct {
    sqlite3: *c.sqlite3,

    pub fn initRO(filename: [:0]const u8) OpenError!Sqlite3 {
        var sqlite3: ?*c.sqlite3 = null;
        if (c.sqlite3_open_v2(filename.ptr, &sqlite3, c.SQLITE_OPEN_READONLY, null) != c.SQLITE_OK or sqlite3 == null) {
            if (sqlite3) |handle| _ = c.sqlite3_close(handle);
            return OpenError.OpenFailed;
        }
        return .{ .sqlite3 = sqlite3.? };
    }

    pub fn deinit(self: *Sqlite3) void {
        _ = c.sqlite3_close(self.sqlite3);
    }

    pub fn stmt(self: *Sqlite3, sql: [:0]const u8) Stmt {
        return Stmt.init(self.sqlite3, sql);
    }
};

const Stmt = struct {
    sqlite3: *c.sqlite3,
    stmt: *c.sqlite3_stmt,

    pub fn init(sqlite3: *c.sqlite3, sql: [:0]const u8) OpenError!Stmt {
        var stmt: *c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(sqlite3, sql.ptr, -1, &stmt, null) != c.SQLITE_OK) {
            return OpenError.OpenFailed;
        }
        return .{ .sqlite3 = sqlite3, .stmt = stmt };
    }

    pub fn deinit(self: *Stmt) void {
        _ = c.sqlite3_finalize(self.stmt);
    }

    pub fn bindtext(self: *Stmt, i: c_int, data: [:0]const u8) void {
        _ = c.sqlite3_bind_text(self.stmt, i, data.ptr, -1, c.SQLITE_TRANSIENT);
    }
};

test "initRO opens an existing database read only" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fs.path.joinZ(std.testing.allocator, &.{
        ".zig-cache",
        "tmp",
        tmp.sub_path[0..],
        "test.db",
    });
    defer std.testing.allocator.free(path);

    var raw: ?*c.sqlite3 = null;
    try std.testing.expectEqual(@as(c_int, c.SQLITE_OK), c.sqlite3_open_v2(path.ptr, &raw, c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE, null));
    try std.testing.expect(raw != null);
    defer {
        if (raw) |handle| _ = c.sqlite3_close(handle);
    }

    try std.testing.expectEqual(@as(c_int, c.SQLITE_OK), c.sqlite3_exec(raw.?, "PRAGMA user_version = 1", null, null, null));
    _ = c.sqlite3_close(raw.?);
    raw = null;

    var db = try Sqlite3.initRO(path);
    defer db.deinit();

    var statement = Sqlite3.stmt();
    try std.testing.expect(!db.prepare(&statement, "SELECT 1"));
    defer _ = c.sqlite3_finalize(statement.?);
}
