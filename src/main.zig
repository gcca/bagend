const std = @import("std");

const bagend = @import("bagend");
const httplib = @import("httplib");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    var server = httplib.Server.init();
    defer server.deinit();

    bagend.handling.auth.routes.initRoutes(server);
    bagend.handling.home.routes.initRoutes(server);
    server
        .Get("/", index)
        .Get("/bagend/healthcheck", healthcheck)
        .listen("0.0.0.0", 8000);
}

fn index(_: httplib.Request, res: httplib.Response) void {
    res.set_redirect("/bagend/auth");
}

fn healthcheck(_: httplib.Request, res: httplib.Response) void {
    res.set_content("🍻", "text/plain");
}
