pub const MessageType = enum(u8) {
    init = 0,
    update = 1,
    custom_init = 2,
    terminate = 3,
    user_input = 4,
    set_refresh_mode = 5,
    request_full_refresh = 6,
};

pub const FramebufferType = enum(u8) {
    rM2_fb = 0,

    rMPP_rgb888 = 1,
    rMPP_rgba8888 = 2,
    rMPP_rgb565 = 3,

    rMPPM_rgb888 = 4,
    rMPPM_rgba8888 = 5,
    rMPPM_rgb565 = 6,

    pub fn getDevice(self: FramebufferType) Device {
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

    vkeyboard_press = 0x40,
    vkeyboard_release = 0x41,
};

pub const InputButton = enum(u32) {
    left = 0,
    home = 1,
    right = 2,
};

pub const InputVKeyboard = enum(u32) {
    shiftmod = 0x100000,
    ctrlmod = 0x200000,
    altmod = 0x400000,
    del = 0x7f,
    pgup = 0x80,
    pgdown = 0x81,
    down = 0x82,
    up = 0x83,
    left = 0x84,
    right = 0x85,
    home = 0x86,
    end = 0x87,
};

pub const UpdateType = enum(i32) {
    all = 0,
    partial = 1,
};

pub const RefreshMode = enum(i32) {
    ufast = 0,
    fast = 1,
    animate = 2,
    content = 3,
    ui = 4,

    pub const default = .ui;
};

pub const FBKey = i32;
pub const Init = extern struct {
    framebuffer_key: FBKey,
    framebuffer_type: FramebufferType,
};

pub const CustomInit = extern struct {
    framebuffer_key: FBKey,
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

    pub const full = UpdateRegion{
        .type = .all,
        .x = 0,
        .y = 0,
        .w = 0,
        .h = 0,
    };
};

pub const Input = extern struct {
    type: InputType,
    device_id: i32,
    x: i32,
    y: i32,
    d: i32,
};

pub const ClientMessage = extern struct {
    type: MessageType,
    message: extern union {
        init: Init,
        update: UpdateRegion,
        custom_init: CustomInit,
        terminate: void,
        refresh_mode: RefreshMode,
        full_refresh: void,
    },

    pub const terminate = ClientMessage{
        .type = .terminate,
        .message = .{ .terminate = {} },
    };

    pub const full_update = ClientMessage{
        .type = .update,
        .message = .{ .update = .full },
    };

    pub const default_mode = ClientMessage{
        .type = .set_refresh_mode,
        .message = .{ .refresh_mode = .default },
    };

    pub const full_refresh = ClientMessage{
        .type = .request_full_refresh,
        .message = .{ .full_refresh = {} },
    };

    pub fn init(
        framebuffer_key: FBKey,
        framebuffer_type: FramebufferType,
    ) ClientMessage {
        return ClientMessage{
            .type = .init,
            .message = .{
                .init = .{
                    .framebuffer_key = framebuffer_key,
                    .framebuffer_type = framebuffer_type,
                },
            },
        };
    }

    pub fn customInit(
        framebuffer_key: FBKey,
        framebuffer_type: FramebufferType,
        width: u16,
        height: u16,
    ) ClientMessage {
        return ClientMessage{
            .type = .custom_init,
            .message = .{
                .custom_init = .{
                    .framebuffer_key = framebuffer_key,
                    .framebuffer_type = framebuffer_type,
                    .width = width,
                    .height = height,
                },
            },
        };
    }

    pub fn update(x: i32, y: i32, w: i32, h: i32) ClientMessage {
        return ClientMessage{
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
        };
    }

    pub fn refreshMode(new_mode: RefreshMode) ClientMessage {
        return ClientMessage{
            .type = .set_refresh_mode,
            .message = .{
                .refresh_mode = new_mode,
            },
        };
    }
};

pub const ServerMessage = extern struct {
    type: MessageType,
    message: extern union {
        init: InitResponse,
        input: Input,
    },
};

const Device = @import("Device.zig").Device;
