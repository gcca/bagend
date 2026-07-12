const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const OpenError = error{
    OpenFailed,
    PrepareFailed,
    StepFailed,
    BindFailed,
};

pub const Step = enum {
    row,
    done,
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

    pub fn stmt(self: *Sqlite3, sql: [:0]const u8) OpenError!Stmt {
        return Stmt.init(self.sqlite3, sql);
    }

    pub fn errmsg(self: *Sqlite3) [:0]const u8 {
        return std.mem.span(c.sqlite3_errmsg(self.sqlite3));
    }
};

pub const Stmt = struct {
    sqlite3: *c.sqlite3,
    stmt: *c.sqlite3_stmt,

    pub fn init(sqlite3: *c.sqlite3, sql: [:0]const u8) OpenError!Stmt {
        var stmt_: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(sqlite3, sql.ptr, -1, &stmt_, null) != c.SQLITE_OK) {
            return OpenError.PrepareFailed;
        }
        return .{ .sqlite3 = sqlite3, .stmt = stmt_.? };
    }

    pub fn deinit(self: *Stmt) void {
        _ = c.sqlite3_finalize(self.stmt);
    }

    pub fn errmsg(self: *Stmt) [:0]const u8 {
        return std.mem.span(c.sqlite3_errmsg(self.sqlite3));
    }

    pub fn bindText(self: *Stmt, i: c_int, data: [:0]const u8) OpenError!void {
        if (c.sqlite3_bind_text(self.stmt, i, data.ptr, -1, c.SQLITE_TRANSIENT) != c.SQLITE_OK) {
            return OpenError.BindFailed;
        }
    }

    pub fn step(self: *Stmt) OpenError!Step {
        return switch (c.sqlite3_step(self.stmt)) {
            c.SQLITE_ROW => .row,
            c.SQLITE_DONE => .done,
            else => OpenError.StepFailed,
        };
    }

    pub fn columnText(self: *Stmt, i: c_int) [:0]const u8 {
        const text = c.sqlite3_column_text(self.stmt, i) orelse return "";
        return std.mem.span(text);
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

    try std.testing.expectEqual(@as(c_int, c.SQLITE_OK), c.sqlite3_exec(raw.?,
        \\CREATE TABLE home_app (
        \\  name TEXT NOT NULL PRIMARY KEY,
        \\  title TEXT NOT NULL,
        \\  description TEXT NOT NULL,
        \\  icon TEXT NOT NULL,
        \\  caption TEXT NOT NULL,
        \\  link TEXT NOT NULL
        \\);
        \\INSERT INTO home_app (name, title, description, icon, caption, link)
        \\VALUES ('tickets', 'Tickets', 'Internal support requests.', 'fa-solid fa-ticket', 'Open', '#');
    , null, null, null));
    _ = c.sqlite3_close(raw.?);
    raw = null;

    var db = try Sqlite3.initRO(path);
    defer db.deinit();

    var statement = try db.stmt("SELECT name, title, description, icon, caption, link FROM home_app");
    defer statement.deinit();
    try std.testing.expectEqual(Step.row, try statement.step());
    try std.testing.expectEqualStrings("tickets", statement.columnText(0));
    try std.testing.expectEqualStrings("Tickets", statement.columnText(1));
    try std.testing.expectEqualStrings("Internal support requests.", statement.columnText(2));
    try std.testing.expectEqualStrings("fa-solid fa-ticket", statement.columnText(3));
    try std.testing.expectEqualStrings("Open", statement.columnText(4));
    try std.testing.expectEqualStrings("#", statement.columnText(5));
    try std.testing.expectEqual(Step.done, try statement.step());
}
