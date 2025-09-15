const std = @import("std");
const zqtfb = @import("zqtfb");
const raw = @embedFile("sample.raw");

var close = false;

fn pollThread(client: *zqtfb.Client) void {
    while (!close) {
        const s = client.pollServerPacket() catch {
            continue;
        };

        if (s.type == .userinput) {
            if (s.message.input.type == .touch_release) {
                close = true;
            }

            const x = s.message.input.x;
            const y = s.message.input.y;

            const i = client.getPixel(x, y);

            client.shm[i] = 0;
            client.shm[i + 1] = 0;
            client.shm[i + 2] = 0;
        }
    }
}

fn updateThread(client: *zqtfb.Client) void {
    while (!close) {
        std.posix.nanosleep(1, 0);
        client.fullUpdate() catch {
            continue;
        };
    }
}

pub fn main() !void {
    // grab the framebuffer ID from AppLoad via QTFB_KEY env variable
    const fb_key = try zqtfb.getIDFromAppLoad();

    // initialize the client, all functions except deinit may fail,
    // so handle errors accordingly
    var c = try zqtfb.Client.init(fb_key, .rMPP_rgb888, null, false);
    defer c.deinit();

    const t = try std.Thread.spawn(.{}, pollThread, .{&c});
    const tt = try std.Thread.spawn(.{}, updateThread, .{&c});

    const m = @min(raw.len, c.shm.len);
    for (0..m) |i| {
        c.shm[i] = raw[i];
    }

    try c.fullUpdate();

    t.join();
    tt.join();
}
