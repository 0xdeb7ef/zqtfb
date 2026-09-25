# zqtfb

A qtfb client implementation in Zig.

## What is a qtfb-client?

Great question! A qtfb client is able to talk to
[AppLoad](https://github.com/asivery/rm-appload) on reMarkable tablets in order to
output to the display.

## How do I import it?

As you would any other Zig library (you need Zig 0.16.0+):

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
You can clone the project as is and run:

```console
zig build
```

To get a `zig-out/bin/example` binary that you can deploy to your reMarkable Paper Pro (check out the [AppLoad](https://github.com/asivery/rm-appload) README for more details).

You may also build the example for other devices with the `-Ddevice` option.

```console
# target the reMarkable 2
zig build -Ddevice=rm2
```
