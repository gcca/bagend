const std = @import("std");
const auth = @import("../zig/auth.pb.zig");

const Allocator = std.mem.Allocator;

pub const UserDetailsRequest = auth.UserDetailsRequest;
pub const UserDetailsResponse = auth.UserDetailsResponse;
pub const AuthenticateRequest = auth.AuthenticateRequest;
pub const AuthenticateResponse = auth.AuthenticateResponse;

pub const user_details_method = "/auth.AuthService/UserDetails";
pub const authenticate_method = "/auth.AuthService/Authenticate";
pub const grpc_proto_content_type = "application/grpc+proto";

pub const CallFn = *const fn (?*anyopaque, []const u8, []const u8, Allocator) anyerror![]u8;

pub const Client = struct {
    allocator: Allocator,
    ctx: ?*anyopaque,
    call: CallFn,

    pub fn init(allocator: Allocator, ctx: ?*anyopaque, call: CallFn) Client {
        return .{
            .allocator = allocator,
            .ctx = ctx,
            .call = call,
        };
    }

    pub fn userDetails(self: Client, username: []const u8) !UserDetailsResponse {
        const request_bytes = try encodeMessage(self.allocator, UserDetailsRequest{ .username = username });
        defer self.allocator.free(request_bytes);

        const response_bytes = try self.call(self.ctx, user_details_method, request_bytes, self.allocator);
        defer self.allocator.free(response_bytes);

        return decodeMessage(UserDetailsResponse, self.allocator, response_bytes);
    }

    pub fn authenticate(self: Client, username: []const u8, password: []const u8) !AuthenticateResponse {
        const request_bytes = try encodeMessage(self.allocator, AuthenticateRequest{
            .username = username,
            .password = password,
        });
        defer self.allocator.free(request_bytes);

        const response_bytes = try self.call(self.ctx, authenticate_method, request_bytes, self.allocator);
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

pub fn encodeGrpcFrame(allocator: Allocator, message: []const u8) ![]u8 {
    if (message.len > std.math.maxInt(u32)) return error.MessageTooLarge;

    const frame = try allocator.alloc(u8, 5 + message.len);
    frame[0] = 0;
    std.mem.writeInt(u32, frame[1..][0..4], @intCast(message.len), .big);
    @memcpy(frame[5..], message);
    return frame;
}

pub fn decodeGrpcFrame(frame: []const u8) ![]const u8 {
    if (frame.len < 5) return error.InvalidGrpcFrame;
    if (frame[0] != 0) return error.CompressedGrpcFrame;

    const len = std.mem.readInt(u32, frame[1..][0..4], .big);
    if (frame.len - 5 != len) return error.InvalidGrpcFrame;

    return frame[5..];
}
