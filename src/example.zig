const std = @import("std");

const zqtfb = @import("zqtfb");

const log = std.log.scoped(.zqtfb_example);

const raw = @embedFile("sample.raw");

var close = false;
var free = true;

fn pollThread(client: *zqtfb.Client, io: std.Io) void {
    while (!close) {
        const s = client.pollServerPacket(io) catch {
            continue;
        };

        switch (s.type) {
            .user_input => {
                switch (s.message.input.type) {
                    .touch_release => {
                        close = true;
                        client.deinit(io);
                        std.process.exit(0);
                        break;
                    },
                    .touch_press, .touch_update => {
                        continue;
                    },
                    .pen_press => {
                        free = false;
                        client.setRefreshMode(io, .ufast) catch unreachable;
                    },
                    .pen_release => {
                        free = true;
                        client.setRefreshMode(io, .default) catch unreachable;
                        continue;
                    },
                    .pen_update => {
                        const x = s.message.input.x;
                        const y = s.message.input.y;

                        pen(client, x, y, 20);

                        client.partialUpdate(io, x - 50, y - 50, 100, 100) catch {};
                    },
                    else => {
                        continue;
                    },
                }
            },
            .device_state_init => {
                log.info(
                    "Device state init: {}",
                    .{s.message.device_state},
                );
            },
            .device_state_changed => {
                log.info(
                    "Device state changed: {}",
                    .{s.message.device_state},
                );
            },
            else => {},
        }
    }
}

fn pen(client: *zqtfb.Client, x: i32, y: i32, width: i32) void {
    const y_start: i32 = std.math.clamp(y - width, 0, client.height);
    const y_end: i32 = std.math.clamp(y + width, 0, client.height);

    const x_start: i32 = std.math.clamp(x - width, 0, client.width);
    const x_end: i32 = std.math.clamp(x + width, 0, client.width);

    const yy_s: usize = @intCast(y_start);
    const yy_e: usize = @intCast(y_end);

    const xx_s: usize = @intCast(x_start);
    const xx_e: usize = @intCast(x_end);

    for (xx_s..xx_e) |xx| {
        for (yy_s..yy_e) |yy| {
            const xxx: i32 = @intCast(xx);
            const yyy: i32 = @intCast(yy);
            const dx = xxx - x;
            const dy = yyy - y;
            const distance_squared = dx * dx + dy * dy;

            if (distance_squared <= width * width) {
                const i = client.getPixel(xxx, yyy);
                for (0..client.getBPS()) |bps| {
                    client.display[i + bps] = 0;
                }
            }
        }
    }
}

pub fn main(init: std.process.Init) !void {
    // grab the framebuffer ID from AppLoad via QTFB_KEY env variable
    const fb_key = try zqtfb.getIDFromAppLoad(init.minimal.environ);

    // get device
    const device = zqtfb.Device.getDevice(init.io) catch |err| {
        std.debug.print("This only runs on reMarkable tablets: {}", .{err});
        return;
    };

    // use rgb_888, or rM2_fb
    const fb_type: zqtfb.Message.FramebufferType = switch (device) {
        .rM2 => .rM2_fb,
        .rMPP => .rMPP_rgb888,
        .rMPPM => .rMPPM_rgb888,
        .rMPPure => .rMPPure_rgb888,
    };

    // initialize the client, all functions except deinit may fail,
    // so handle errors accordingly
    var c = try zqtfb.Client.init(init.io, fb_key, fb_type, null, false);
    defer c.deinit(init.io);

    const t = try std.Thread.spawn(.{}, pollThread, .{ &c, init.io });

    const m = @min(raw.len, c.display.len);
    for (0..m) |i| {
        c.display[i] = raw[i];
    }

    try c.fullUpdate(init.io);

    t.join();
}
