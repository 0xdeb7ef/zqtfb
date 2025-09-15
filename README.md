# zqtfb

A qtfb client implementation in Zig.

## What is a qtfb-client?

Great question! A qtfb client is able to talk to
[AppLoad](https://github.com/asivery/rm-appload) on reMarkable tablets in order to
output to the display.

## How do I import it?

As you would any other Zig library (you need Zig 0.15.1+):

```
zig fetch --save git+https://github.com/0xdeb7ef/zqtfb.git
```

And in your `build.zig`:

```zig
const zqtfb = b.dependency("zqtfb", .{});
exe.root_module.addImport("zqtfb", zqtfb.module("zqtfb"));
```

## How do I use it?

There is an `example.zig` file in `src`.
You can clone the project as in and run:

```
zig build -Dtarget=aarch64-linux-gnu
```

To get a `zig-out/bin/example` binary that you can deploy to your reMarkable Paper Pro (check out the [AppLoad](https://github.com/asivery/rm-appload) README for more details).

(I have not tested other devices, but it should work on the rM2 and Move as well, you
just have to compile for the right architecture, and pick the right framebuffer type).

## TODO

- [ ] The code at the moment is not very Zig-like, so it would be better to update
      it and make it more Zig-like maybe?
- [ ] Add some tests, perhaps?
- [ ] More robust error handling, currently all errors are ignored with `try`.
