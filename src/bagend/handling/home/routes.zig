const std = @import("std");

const httplib = @import("httplib");
const mustache = @import("mustache");
const sqlite3 = @import("sqlite3");

const homeTmpl = @embedFile("tmpl/home.html");
const cardTmpl = @embedFile("tmpl/card.html");
const databasePath = "db/bagend.db";
const appsSql =
    \\SELECT name, title, description, icon, caption, link
    \\FROM home_app
    \\ORDER BY rowid
;

pub fn initRoutes(server: httplib.Server) void {
    _ = server
        .Get("/bagend/home", homeGet);
}

fn homeGet(_: httplib.Request, res: httplib.Response) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db = sqlite3.Sqlite3.initRO(databasePath) catch {
        res.set_content("failed to open database", "text/plain");
        return;
    };
    defer db.deinit();

    var stmt = db.stmt(appsSql) catch {
        std.debug.print("failed to prepare home apps query: {s}\n", .{db.errmsg()});
        res.set_content("failed to load applications", "text/plain");
        return;
    };
    defer stmt.deinit();

    var card = mustache.Mustache.init(allocator, cardTmpl);
    defer card.deinit();

    var cardsHtml: std.ArrayList(u8) = .empty;
    while (true) {
        switch (stmt.step() catch {
            std.debug.print("failed to step home apps query: {s}\n", .{stmt.errmsg()});
            res.set_content("failed to load applications", "text/plain");
            return;
        }) {
            .row => {},
            .done => break,
        }

        var data = mustache.Data.init(allocator);
        defer data.deinit();
        data.setString("title", stmt.columnText(1));
        data.setString("description", stmt.columnText(2));
        data.setString("icon", stmt.columnText(3));
        data.setString("caption", stmt.columnText(4));
        data.setString("link", stmt.columnText(5));

        const rendered = card.Render(data);
        cardsHtml.appendSlice(allocator, rendered) catch @panic("OOM");
    }

    var dashboard = mustache.Mustache.init(allocator, homeTmpl);
    defer dashboard.deinit();

    var data = mustache.Data.init(allocator);
    defer data.deinit();
    const cardsZ = allocator.dupeZ(u8, cardsHtml.items) catch @panic("OOM");
    data.setString("cards", cardsZ);

    const rendered = dashboard.Render(data);
    res.set_content(rendered, "text/html");
}
