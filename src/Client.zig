//! Implementaion of qtfb-client in Zig

/// Client struct that holds the shared memory buffer
/// and socket to communicate with AppLoad.
pub const Client = struct {
    display: []align(std.heap.page_size_min) u8,
    socket: std.Io.net.Stream,
    width: u16,
    height: u16,
    refresh_mode: RefreshMode = .default,

    const SOCKET_PATH = "/tmp/qtfb.sock";
    var socket_path: [108]u8 = @splat(0);

    /// Initializes the Client connection to AppLoad
    pub fn init(
        io: std.Io,
        /// framebuffer ID, use `getIDFromAppLoad` to get the correct ID
        framebuffer_id: i32,
        /// frambuffer type, see `Message.FramebufferType`
        display_type: FramebufferType,
        /// custom resolution, if needed
        custom_resolution: ?struct { width: u16, height: u16 },
        /// whether to put the socket in non-blocking mode
        non_blocking: bool,
    ) !Client {
        var client: Client = undefined;

        @memcpy(socket_path[0..SOCKET_PATH.len], SOCKET_PATH);

        const sockfd = linux.socket(linux.AF.UNIX, linux.SOCK.SEQPACKET, 0);
        const addr: linux.sockaddr.un = .{ .family = linux.AF.UNIX, .path = socket_path };

        const r = linux.connect(@intCast(sockfd), &addr, @sizeOf(@TypeOf(addr)));
        if (r != 0) return error.UnspecifiedSockError;

        const sock: std.Io.net.Stream = .{ .socket = .{
            .handle = @intCast(sockfd),
            .address = undefined,
        } };

        var write_buf: [@sizeOf(Message.ClientMessage)]u8 = undefined;
        var socket_w = sock.writer(io, &write_buf);
        const socket_writer = &socket_w.interface;

        var read_buf: [@sizeOf(Message.ServerMessage)]u8 = undefined;
        var socket_r = sock.reader(io, &read_buf);
        const socket_reader = &socket_r.interface;

        var init_message: Message.ClientMessage = undefined;
        if (custom_resolution) |cr| {
            client.width = cr.width;
            client.height = cr.height;

            init_message = .{
                .type = .custom_init,
                .message = .{
                    .custom_init = .{
                        .framebuffer_key = framebuffer_id,
                        .framebuffer_type = display_type,
                        .width = client.width,
                        .height = client.height,
                    },
                },
            };
        } else {
            client.width = display_type.getWidth();
            client.height = display_type.getHeight();

            init_message = .{
                .type = .init,
                .message = .{
                    .init = .{
                        .framebuffer_key = framebuffer_id,
                        .framebuffer_type = display_type,
                    },
                },
            };
        }

        try socket_writer.writeStruct(init_message, .little);
        try socket_writer.flush();

        const server_response = try socket_reader.takeStruct(Message.ServerMessage, .little);

        if (non_blocking) {
            const status = linux.fcntl(sock.socket.handle, linux.F.GETFL, 0);
            var flags: linux.O = @bitCast(@as(u32, @truncate(status)));
            flags.NONBLOCK = true;
            const f: usize = @as(usize, @as(u32, @bitCast(flags)));
            _ = linux.fcntl(sock.socket.handle, linux.F.SETFL, f);
        }

        var shm_name_buf: [20]u8 = @splat(0);
        const shm_name = try std.fmt.bufPrintZ(
            &shm_name_buf,
            "/qtfb_{d}",
            .{server_response.message.init.shm_key},
        );

        const shm = std.c.shm_open(
            shm_name,
            @bitCast(linux.O{ .ACCMODE = .RDWR }),
            0,
        );

        const m = linux.mmap(
            null,
            server_response.message.init.shm_size,
            // linux.PROT.READ | linux.PROT.WRITE,
            linux.PROT{ .READ = true, .WRITE = true },
            linux.MAP{ .TYPE = .SHARED },
            shm,
            0,
        );
        var memory: []align(std.heap.page_size_min) u8 = undefined;
        memory.ptr = @ptrFromInt(m);
        memory.len = server_response.message.init.shm_size;

        client.display = memory;
        client.socket = sock;

        return client;
    }

    /// Cleans up the memory mapping and closes the socket
    pub fn deinit(self: *Client, io: std.Io) void {
        _ = linux.munmap(self.display.ptr, self.display.len);

        self.send(io, .terminate) catch {};
        self.socket.close(io);
    }

    /// Asks AppLoad to refresh the full display
    pub fn fullUpdate(self: *Client, io: std.Io) !void {
        try self.send(io, .full_update);
    }

    /// Asks AppLoad to do a partial display refresh.
    pub fn partialUpdate(
        self: *Client,
        io: std.Io,
        /// x coordinate
        x: i32,
        /// y coordinate
        y: i32,
        /// width
        w: i32,
        /// height
        h: i32,
    ) !void {
        try self.send(io, .{
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

    /// Requests a full refresh.
    pub fn fullRefresh(self: *Client, io: std.Io) !void {
        try self.send(io, .full_refresh);
    }

    /// Set the display refresh mode.
    pub fn setRefreshMode(self: *Client, io: std.Io, mode: RefreshMode) !void {
        try self.send(io, .{
            .type = .set_refresh_mode,
            .message = .{ .refresh_mode = mode },
        });

        self.refresh_mode = mode;
    }

    /// Reset the display to default refresh mode.
    pub fn resetRefreshMode(self: *Client, io: std.Io) !void {
        try self.send(io, .default_mode);
        self.refresh_mode = .default;
    }

    /// Gets the current refresh mode.
    pub fn getRefreshMode(self: Client) RefreshMode {
        return self.refresh_mode;
    }

    /// Retrieves a packet from AppLoad
    pub fn pollServerPacket(self: *Client, io: std.Io) !Message.ServerMessage {
        var read_buf: [@sizeOf(Message.ServerMessage)]u8 = undefined;
        var socket_r = self.socket.reader(io, &read_buf);
        const socket_reader = &socket_r.interface;

        return socket_reader.takeStruct(Message.ServerMessage, .little);
    }

    fn send(self: *Client, io: std.Io, msg: Message.ClientMessage) !void {
        var write_buf: [@sizeOf(Message.ClientMessage)]u8 = undefined;

        var socket_w = self.socket.writer(io, &write_buf);
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

        return self.display.len / ww / hh;
    }
};

/// Gets the framebuffer ID from `QTFB_KEY`
pub fn getIDFromAppLoad(env: std.process.Environ) !i32 {
    const key = env.getPosix("QTFB_KEY") orelse {
        return error.NoAppload;
    };

    return try std.fmt.parseInt(i32, key, 10);
}

const std = @import("std");
const linux = std.os.linux;

const Message = @import("Message.zig");
const FramebufferType = Message.FramebufferType;
const RefreshMode = Message.RefreshMode;
