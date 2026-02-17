const std = @import("std");

const zqtfb = @import("zqtfb");

const raw = @embedFile("sample.raw");

var close = false;
var free = true;

fn pollThread(client: *zqtfb.Client, io: std.Io) void {
    while (!close) {
        const s = client.pollServerPacket(io) catch {
            continue;
        };

        if (s.type == .user_input) {
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
                    client.setRefreshMode(io, .animate) catch {};
                },
                .pen_release => {
                    free = true;
                    client.setRefreshMode(io, .content) catch {};
                    continue;
                },
                else => {},
            }

            const x = s.message.input.x;
            const y = s.message.input.y;

            pen(client, x, y, 20);

            client.partialUpdate(io, x - 50, y - 50, 100, 100) catch {};
        }
    }
}

fn pen(client: *zqtfb.Client, x: i32, y: i32, width: i32) void {
    const y_start: i32 = @max(0, y - width);
    const y_end: i32 = @min(y + width, client.width);

    const x_start: i32 = @max(0, x - width);
    const x_end: i32 = @min(x + width, client.height);

    const yy_s: usize = @intCast(y_start);
    const yy_e: usize = @intCast(y_end);

    const xx_s: usize = @intCast(x_start);
    const xx_e: usize = @intCast(x_end);

    for (yy_s..yy_e) |yy| {
        for (xx_s..xx_e) |xx| {
            const xxx: i32 = @intCast(xx);
            const yyy: i32 = @intCast(yy);
            const dx = xxx - x;
            const dy = yyy - y;
            const distance_squared = dx * dx + dy * dy;

            if (distance_squared <= width * width) {
                const i = client.getPixel(xxx, yyy);
                client.display[i] = 0;
                client.display[i + 1] = 0;
                client.display[i + 2] = 0;
            }
        }
    }
}

fn updateThread(client: *zqtfb.Client, io: std.Io) void {
    while (!close) {
        _ = std.os.linux.nanosleep(&.{ .sec = 10, .nsec = 0 }, null);

        if (free) {
            client.fullRefresh(io) catch {
                continue;
            };
        }
    }
}

pub fn main(init: std.process.Init) !void {
    // grab the framebuffer ID from AppLoad via QTFB_KEY env variable
    const fb_key = try zqtfb.getIDFromAppLoad(init.minimal.environ);

    // initialize the client, all functions except deinit may fail,
    // so handle errors accordingly
    var c = try zqtfb.Client.init(init.io, fb_key, .rMPP_rgb888, null, false);
    defer c.deinit(init.io);

    const t = try std.Thread.spawn(.{}, pollThread, .{ &c, init.io });
    const tt = try std.Thread.spawn(.{}, updateThread, .{ &c, init.io });

    const m = @min(raw.len, c.display.len);
    for (0..m) |i| {
        c.display[i] = raw[i];
    }

    try c.fullUpdate(init.io);

    t.join();
    tt.join();
}
