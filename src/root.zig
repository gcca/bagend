pub const core = struct {
    pub const urmom = @import("core/urmom.zig");
};

pub const handling = struct {
    pub const auth = struct {
        pub const routes = @import("bagend/handling/auth/routes.zig");
    };
    pub const home = struct {
        pub const routes = @import("bagend/handling/home/routes.zig");
    };
};
