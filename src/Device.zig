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
};
