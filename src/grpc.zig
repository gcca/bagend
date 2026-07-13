const std = @import("std");

const c = @cImport({
    @cInclude("grpcshim.hpp");
});

pub const Client = struct {
    handle: *c.GrpcAuthClient,

    pub fn init(target: [:0]const u8) !Client {
        const handle = c.grpc_auth_client_create(target.ptr) orelse return error.GrpcClientInitFailed;
        return .{ .handle = handle };
    }

    pub fn deinit(self: *Client) void {
        c.grpc_auth_client_destroy(self.handle);
    }

    pub fn unary(self: Client, allocator: std.mem.Allocator, method: [:0]const u8, request: []const u8) ![]u8 {
        const response = c.grpc_auth_client_unary(
            self.handle,
            method.ptr,
            request.ptr,
            request.len,
            5000,
        );
        if (response.data == null) return error.GrpcCallFailed;
        defer c.grpc_buffer_destroy(response);

        return allocator.dupe(u8, response.data[0..response.len]);
    }

    pub fn lastError(self: Client) []const u8 {
        return std.mem.span(c.grpc_auth_client_last_error(self.handle));
    }
};
