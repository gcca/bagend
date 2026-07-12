const std = @import("std");

const httplib = @import("httplib");
const mustache = @import("mustache");

const signInTmpl = @embedFile("tmpl/signin.html");
const dashboardTmpl = @embedFile("tmpl/dashboard.html");

pub fn initRoutes(server: httplib.Server) void {
    _ = server
        .Get("/bagend/auth/signin", signInGet)
        .Post("/bagend/auth/signin", signInPost)
        .Get("/bagend/auth", indexGet);
}

fn indexGet(_: httplib.Request, res: httplib.Response) void {
    res.set_redirect("/bagend/auth/signin");
}

fn signInGet(_: httplib.Request, res: httplib.Response) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var tmpl = mustache.Mustache.init(arena.allocator(), signInTmpl);
    defer tmpl.deinit();

    var data = mustache.Data.init(arena.allocator());
    defer data.deinit();

    const rendered = tmpl.Render(data);

    res.set_content(rendered, "text/html");
}

fn signInPost(_: httplib.Request, res: httplib.Response) void {
    res.set_redirect("/bagend/home");
}
