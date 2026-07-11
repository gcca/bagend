const std = @import("std");

const c = @cImport({
    @cInclude("mustacheshim.hpp");
});

const RenderCtx = struct {
    allocator: std.mem.Allocator,
    buf: std.ArrayList(u8),
};

fn RenderHandler(p: ?*anyopaque, data: [*c]const u8, len: usize) callconv(.c) void {
    const ctx: *RenderCtx = @ptrCast(@alignCast(p.?));
    ctx.buf.appendSlice(ctx.allocator, data[0..len]) catch @panic("OOM");
}

pub const Mustache = struct {
    mustache: *c.Mustache,
    allocator: std.mem.Allocator,
    mem: []u8,
    memalign: std.mem.Alignment,

    pub fn init(allocator: std.mem.Allocator, s: [:0]const u8) Mustache {
        const memlen: usize = c.MustacheSize;
        const memalign = std.mem.Alignment.fromByteUnits(c.MustacheAlign);
        const memptr = allocator.rawAlloc(memlen, memalign, @returnAddress()) orelse @panic("OOM");
        const mem = memptr[0..memlen];
        return .{
            .mustache = c.mustache_init(mem.ptr, s.ptr).?,
            .allocator = allocator,
            .mem = mem,
            .memalign = memalign,
        };
    }

    pub fn deinit(self: *Mustache) void {
        c.mustache_deinit(self.mustache);
        self.allocator.rawFree(self.mem, self.memalign, @returnAddress());
    }

    pub fn Render(self: *Mustache) [:0]u8 {
        var ctx: RenderCtx = .{ .allocator = self.allocator, .buf = .empty };
        c.mustache_render(self.mustache, RenderHandler, &ctx);
        return ctx.buf.toOwnedSliceSentinel(self.allocator, 0) catch @panic("OOM");
    }
};

test "render" {
    var m = Mustache.Init(std.testing.allocator, "hello {{! comment }}world");
    defer m.Deinit();
    const rendered = m.Render();
    defer std.testing.allocator.free(rendered);
    try std.testing.expectEqualStrings("hello world", rendered);
}
