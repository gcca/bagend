const std = @import("std");

const bagend = @import("bagend");
const httplib = @import("httplib");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    var auth_client = try bagend.core.urmom.AuthClient.init(arena, "localhost:50051");
    defer auth_client.deinit();

    var user_details = try auth_client.UserDetails(.{ .username = "jill.valentine" });
    defer user_details.deinit(arena);

    std.debug.print("UserDetails(jill.valentine): is_active={} apps=", .{user_details.is_active});
    for (user_details.apps.items, 0..) |app, i| {
        if (i > 0) std.debug.print(",", .{});
        std.debug.print("{s}", .{app});
    }
    std.debug.print("\n", .{});

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
