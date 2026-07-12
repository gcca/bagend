const c = @cImport({
    @cInclude("httplibshim.hpp");
});

pub const Request = struct {
    handle: *const c.Request,
};

pub const Response = struct {
    handle: *c.Response,

    pub fn set_redirect(self: Response, url: [:0]const u8) void {
        c.response_set_redirect(self.handle, url.ptr);
    }

    pub fn set_content(self: Response, s: []const u8, content_type: [:0]const u8) void {
        c.response_set_content(self.handle, s.ptr, s.len, content_type.ptr);
    }
};

pub const Handler = fn (Request, Response) void;

pub const Server = struct {
    handle: *c.Server,

    pub fn init() Server {
        return .{ .handle = c.server_create().? };
    }

    pub fn deinit(self: *Server) void {
        c.server_destroy(self.handle);
    }

    pub fn Get(self: Server, pattern: [:0]const u8, comptime handler: Handler) Server {
        c.server_get(self.handle, pattern.ptr, struct {
            fn call(req: ?*const c.Request, res: ?*c.Response) callconv(.c) void {
                handler(.{ .handle = req.? }, .{ .handle = res.? });
            }
        }.call);
        return self;
    }

    pub fn Post(self: Server, pattern: [:0]const u8, comptime handler: Handler) Server {
        c.server_post(self.handle, pattern.ptr, struct {
            fn call(req: ?*const c.Request, res: ?*c.Response) callconv(.c) void {
                handler(.{ .handle = req.? }, .{ .handle = res.? });
            }
        }.call);
        return self;
    }

    pub fn Put(self: Server, pattern: [:0]const u8, comptime handler: Handler) Server {
        c.server_put(self.handle, pattern.ptr, struct {
            fn call(req: ?*const c.Request, res: ?*c.Response) callconv(.c) void {
                handler(.{ .handle = req.? }, .{ .handle = res.? });
            }
        }.call);
        return self;
    }

    pub fn Delete(self: Server, pattern: [:0]const u8, comptime handler: Handler) Server {
        c.server_delete(self.handle, pattern.ptr, struct {
            fn call(req: ?*const c.Request, res: ?*c.Response) callconv(.c) void {
                handler(.{ .handle = req.? }, .{ .handle = res.? });
            }
        }.call);
        return self;
    }

    pub fn listen(self: Server, host: [:0]const u8, port: c_int) void {
        c.server_listen(self.handle, host.ptr, port);
    }
};
