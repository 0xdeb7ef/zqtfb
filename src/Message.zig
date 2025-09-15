pub const MessageType = enum(u8) {
    init = 0,
    update = 1,
    custom_init = 2,
    terminate = 3,
    userinput = 4,
};

pub const FramebufferType = enum(u8) {
    rM2_fb = 0,

    rMPP_rgb888 = 1,
    rMPP_rgba8888 = 2,
    rMPP_rgb565 = 3,

    rMPPM_rgb888 = 4,
    rMPPM_rgba8888 = 5,
    rMPPM_rgb565 = 6,

    fn getDevice(self: FramebufferType) Device {
        return switch (self) {
            .rM2_fb => .rM2,
            .rMPP_rgb888, .rMPP_rgba8888, .rMPP_rgb565 => .rMPP,
            .rMPPM_rgb888, .rMPPM_rgba8888, .rMPPM_rgb565 => .rMPPM,
        };
    }

    pub fn getWidth(self: FramebufferType) u16 {
        return self.getDevice().getWidth();
    }

    pub fn getHeight(self: FramebufferType) u16 {
        return self.getDevice().getHeight();
    }
};

pub const InputType = enum(i32) {
    touch_press = 0x10,
    touch_release = 0x11,
    touch_update = 0x12,

    pen_press = 0x20,
    pen_release = 0x21,
    pen_update = 0x22,

    button_press = 0x30,
    button_release = 0x31,
};

pub const InputButton = enum(u32) {
    left = 0,
    home = 1,
    right = 2,
};

pub const UpdateType = enum(i32) {
    all = 0,
    partial = 1,
};

pub const Init = extern struct {
    framebuffer_key: i32,
    framebuffer_type: FramebufferType,
};

pub const CustomInit = extern struct {
    framebuffer_key: i32,
    framebuffer_type: FramebufferType,
    width: u16,
    height: u16,
};

pub const InitResponse = extern struct {
    shm_key: i32,
    shm_size: usize,
};

pub const UpdateRegion = extern struct {
    type: UpdateType,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

pub const Input = extern struct {
    type: InputType,
    device_id: i32,
    x: i32,
    y: i32,
    d: i32,
};

pub const Terminate = extern struct {};

pub const ClientMessage = extern struct {
    type: MessageType,
    message: extern union {
        init: Init,
        update: UpdateRegion,
        custom_init: CustomInit,
        terminate: Terminate,
    },

    pub const terminate = ClientMessage{
        .type = .terminate,
        .message = .{ .terminate = .{} },
    };
};

pub const ServerMessage = extern struct {
    type: MessageType,
    message: extern union {
        init: InitResponse,
        input: Input,
    },
};

const Device = @import("Device.zig").Device;
