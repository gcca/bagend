const std = @import("std");

const httplib = @import("httplib");
const mustache = @import("mustache");

const signInTmpl = @embedFile("tmpl/signin.html");

pub fn initRoutes(server: httplib.Server) httplib.Server {
    return server
        .Get("/bagend/auth/signin", signInGet)
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

    const rendered = tmpl.Render();

    res.set_content(rendered, "text/html");
}

fn signInPost(_: httplib.Request, res: httplib.Response) void {
    res.set_redirect("/bagend/home");
}
