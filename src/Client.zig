//! Implementaion of qtfb-client in Zig

/// Client struct that holds all shared memory buffer
/// and socket to communicate with AppLoad.
pub const Client = struct {
    shm: []align(std.heap.page_size_min) u8,
    socket: std.net.Stream,
    width: u16,
    height: u16,

    /// Initializes the Client connection to AppLoad
    pub fn init(
        /// framebuffer ID, use `getIDFromAppLoad` to get the correct ID
        framebuffer_id: i32,
        /// frambuffer type, see `Message.FramebufferType`
        shm_type: FramebufferType,
        /// custom resolution, if needed
        custom_resolution: ?struct { width: u16, height: u16 },
        /// whether to put the socket in non-blocking mode
        non_blocking: bool,
    ) !Client {
        var client: Client = undefined;

        const sockfd = try posix.socket(posix.AF.UNIX, posix.SOCK.SEQPACKET, 0);
        const addr = try std.net.Address.initUnix("/tmp/qtfb.sock");
        try posix.connect(sockfd, &addr.any, addr.getOsSockLen());
        const sock: std.net.Stream = .{ .handle = sockfd };

        var write_buf: [@sizeOf(Message.ClientMessage)]u8 = undefined;
        var socket_w = sock.writer(&write_buf);
        const socket_writer = &socket_w.interface;

        var read_buf: [@sizeOf(Message.ServerMessage)]u8 = undefined;
        var socket_r = sock.reader(&read_buf);
        const socket_reader = socket_r.interface();

        var init_message: Message.ClientMessage = undefined;
        if (custom_resolution != null) {
            client.width = custom_resolution.?.width;
            client.height = custom_resolution.?.height;

            init_message = .{
                .type = .custom_init,
                .message = .{
                    .custom_init = .{
                        .framebuffer_key = framebuffer_id,
                        .framebuffer_type = shm_type,
                        .width = client.width,
                        .height = client.height,
                    },
                },
            };
        } else {
            client.width = shm_type.getWidth();
            client.height = shm_type.getHeight();

            init_message = .{
                .type = .init,
                .message = .{
                    .init = .{
                        .framebuffer_key = framebuffer_id,
                        .framebuffer_type = shm_type,
                    },
                },
            };
        }

        try socket_writer.writeStruct(init_message, .little);
        try socket_writer.flush();

        const server_response = try socket_reader.takeStruct(Message.ServerMessage, .little);

        if (non_blocking) {
            const status = try posix.fcntl(sock.handle, posix.F.GETFL, 0);
            var flags: posix.O = @bitCast(@as(u32, @truncate(status)));
            flags.NONBLOCK = true;
            const f: usize = @as(usize, @as(u32, @bitCast(flags)));
            _ = try posix.fcntl(sock.handle, posix.F.SETFL, f);
        }

        var shm_name_buf: [20]u8 = @splat(0);
        const shm_name = try std.fmt.bufPrintZ(
            &shm_name_buf,
            "/qtfb_{d}",
            .{server_response.message.init.shm_key},
        );

        const shm = std.c.shm_open(
            shm_name,
            @bitCast(posix.O{ .ACCMODE = .RDWR }),
            0,
        );

        const memory: []align(std.heap.page_size_min) u8 = try posix.mmap(
            null,
            server_response.message.init.shm_size,
            posix.PROT.READ | posix.PROT.WRITE,
            posix.MAP{ .TYPE = .SHARED },
            shm,
            0,
        );

        client.shm = memory;
        client.socket = sock;

        return client;
    }

    /// Cleans up the memory mapping and closes the socket
    pub fn deinit(self: *Client) void {
        posix.munmap(self.shm);

        const msg: Message.ClientMessage = .terminate;
        self.send(msg) catch {};
        self.socket.close();
    }

    /// Asks AppLoad to refresh the full display
    pub fn fullUpdate(self: *Client) !void {
        try self.send(.{
            .type = .update,
            .message = .{
                .update = .{
                    .type = .all,
                    .x = 0,
                    .y = 0,
                    .w = 0,
                    .h = 0,
                },
            },
        });
    }

    /// Asks AppLoad to do a partial display refresh.
    /// At the time of writing, seems to behave the same
    /// as a full display refresh.
    pub fn partialUpdate(
        self: *Client,
        /// x coordinate
        x: i32,
        /// y coordinate
        y: i32,
        /// width
        w: i32,
        /// height
        h: i32,
    ) !void {
        try self.send(.{
            .type = .update,
            .message = .{
                .update = .{
                    .type = .partial,
                    .x = x,
                    .y = y,
                    .w = w,
                    .h = h,
                },
            },
        });
    }

    /// Retrieves a packet from AppLoad
    pub fn pollServerPacket(self: *Client) !Message.ServerMessage {
        var read_buf: [@sizeOf(Message.ServerMessage)]u8 = undefined;
        var socket_r = self.socket.reader(&read_buf);
        const socket_reader = &socket_r.file_reader.interface;

        return socket_reader.takeStruct(Message.ServerMessage, .little);
    }

    fn send(self: *Client, msg: Message.ClientMessage) !void {
        var write_buf: [@sizeOf(Message.ClientMessage)]u8 = undefined;

        var socket_w = self.socket.writer(&write_buf);
        const socket_writer = &socket_w.interface;

        try socket_writer.writeStruct(msg, .little);
        try socket_writer.flush();
    }

    /// Helper function to easily transform (x,y) coordinates into
    /// an array index that works with the flat shared memory buffer.
    pub fn getPixel(self: Client, x: i32, y: i32) usize {
        const xx: usize = @intCast(x);
        const yy: usize = @intCast(y);

        return (yy * self.width + xx) * self.getBPS();
    }

    /// Helper function to return the bits per pixel.
    pub fn getBPS(self: Client) usize {
        const ww: usize = @intCast(self.width);
        const hh: usize = @intCast(self.height);

        return self.shm.len / ww / hh;
    }
};

/// Gets the framebuffer ID from `QTFB_KEY`
pub fn getIDFromAppLoad() !i32 {
    const key = posix.getenv("QTFB_KEY") orelse {
        return error.NoAppload;
    };

    return try std.fmt.parseInt(i32, key, 10);
}

const std = @import("std");
const posix = std.posix;
const Message = @import("Message.zig");
const FramebufferType = Message.FramebufferType;
