const std = @import("std");

const httplib = @import("httplib");
const mustache = @import("mustache");

const homeTmpl = @embedFile("tmpl/home.html");
const cardTmpl = @embedFile("tmpl/card.html");

pub fn initRoutes(server: httplib.Server) void {
    _ = server
        .Get("/bagend/home", homeGet);
}

const App = struct {
    name: [:0]const u8,
    title: [:0]const u8,
    description: [:0]const u8,
    icon: [:0]const u8,
    caption: [:0]const u8,
    link: [:0]const u8,
};

const apps = [_]App{
    .{
        .name = "tickets",
        .title = "Tickets",
        .description = "Gestión de solicitudes y soporte interno.",
        .icon = "fa-solid fa-ticket",
        .caption = "Abrir",
        .link = "#",
    },
    .{
        .name = "tablero",
        .title = "Tablero",
        .description = "Indicadores comerciales y operativos.",
        .icon = "fa-solid fa-chart-line",
        .caption = "Ver tablero",
        .link = "#",
    },
    .{
        .name = "asistencia",
        .title = "Asistencia",
        .description = "Control de asistencia del personal.",
        .icon = "fa-solid fa-clipboard-check",
        .caption = "Registrar",
        .link = "#",
    },
    .{
        .name = "reportes",
        .title = "Reportes",
        .description = "Reportes de ventas y ocupación.",
        .icon = "fa-solid fa-file-lines",
        .caption = "Consultar",
        .link = "#",
    },
};

fn homeGet(_: httplib.Request, res: httplib.Response) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var card = mustache.Mustache.init(allocator, cardTmpl);
    defer card.deinit();

    var cardsHtml: std.ArrayList(u8) = .empty;
    for (apps) |app| {
        var data = mustache.Data.init(allocator);
        defer data.deinit();
        data.setString("title", app.title);
        data.setString("description", app.description);
        data.setString("icon", app.icon);
        data.setString("caption", app.caption);
        data.setString("link", app.link);

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
