const std = @import("std");
const plugin = @import("clap/plugin.zig");

pub fn main() u8 {
    std.debug.print("savera smoke: descriptor {s} exposes a fixed-capacity sine voice\n", .{plugin.id});
    return 0;
}
