const std = @import("std");
const grpc = @import("grpc");
const auth = @import("../zig/auth.pb.zig");

const Allocator = std.mem.Allocator;
const Service = auth.AuthService(void, anyerror);

pub const UserDetailsRequest = auth.UserDetailsRequest;
pub const UserDetailsResponse = auth.UserDetailsResponse;
pub const AuthenticateRequest = auth.AuthenticateRequest;
pub const AuthenticateResponse = auth.AuthenticateResponse;

const user_details_method: [:0]const u8 = "/" ++ Service.package ++ "." ++ Service.service_name ++ "/UserDetails";
const authenticate_method: [:0]const u8 = "/" ++ Service.package ++ "." ++ Service.service_name ++ "/Authenticate";

pub const AuthClient = struct {
    allocator: Allocator,
    client: grpc.Client,

    pub fn init(allocator: Allocator, target: [:0]const u8) !AuthClient {
        return .{
            .allocator = allocator,
            .client = try grpc.Client.init(target),
        };
    }

    pub fn deinit(self: *AuthClient) void {
        self.client.deinit();
    }

    pub fn UserDetails(self: AuthClient, request: UserDetailsRequest) !UserDetailsResponse {
        const request_bytes = try encodeMessage(self.allocator, request);
        defer self.allocator.free(request_bytes);

        const response_bytes = self.client.unary(self.allocator, user_details_method, request_bytes) catch |err| {
            std.log.err("grpc {s}: {s}", .{ user_details_method, self.client.lastError() });
            return err;
        };
        defer self.allocator.free(response_bytes);

        return decodeMessage(UserDetailsResponse, self.allocator, response_bytes);
    }

    pub fn Authenticate(self: AuthClient, request: AuthenticateRequest) !AuthenticateResponse {
        const request_bytes = try encodeMessage(self.allocator, request);
        defer self.allocator.free(request_bytes);

        const response_bytes = self.client.unary(self.allocator, authenticate_method, request_bytes) catch |err| {
            std.log.err("grpc {s}: {s}", .{ authenticate_method, self.client.lastError() });
            return err;
        };
        defer self.allocator.free(response_bytes);

        return decodeMessage(AuthenticateResponse, self.allocator, response_bytes);
    }
};

pub fn encodeMessage(allocator: Allocator, message: anytype) ![]u8 {
    var writer: std.Io.Writer.Allocating = .init(allocator);
    errdefer writer.deinit();

    try message.encode(&writer.writer, allocator);

    return writer.toOwnedSlice();
}

pub fn decodeMessage(comptime T: type, allocator: Allocator, bytes: []const u8) !T {
    var reader: std.Io.Reader = .fixed(bytes);
    return T.decode(&reader, allocator);
}
