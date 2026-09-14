const std = @import("std");

pub const Device = enum {
    rM2,
    rMPP,
    rMPPM,

    pub fn getWidth(self: Device) u16 {
        return switch (self) {
            .rM2 => 1404,
            .rMPP => 1620,
            .rMPPM => 954,
        };
    }

    pub fn getHeight(self: Device) u16 {
        return switch (self) {
            .rM2 => 1872,
            .rMPP => 2160,
            .rMPPM => 1696,
        };
    }

    pub fn getDevice(io: std.Io) error{NonReMarkable}!Device {
        const device_file = std.Io.Dir.cwd().openFile(io, "/sys/devices/soc0/machine", .{}) catch {
            return error.NonReMarkable;
        };
        defer device_file.close(io);

        var buf: [64]u8 = undefined;

        _ = device_file.readPositionalAll(io, &buf, 0) catch unreachable;

        if (std.mem.containsAtLeast(u8, &buf, 1, "Chiappa")) {
            return .rMPPM;
        } else if (std.mem.containsAtLeast(u8, &buf, 1, "Ferrari")) {
            return .rMPP;
        } else if (std.mem.containsAtLeast(u8, &buf, 1, "2.0")) {
            return .rM2;
        } else {
            return .rM2; // rM1 has same res as rM2
        }
    }
};
