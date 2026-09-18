const std = @import("std");
const clap = @import("clap/c.zig");
const plugin = @import("clap/plugin.zig");
const build_options = @import("build_options");
const c = clap.c;

export fn savera_clap_init(path: [*c]const u8) callconv(.c) bool {
    _ = path;
    return true;
}

export fn savera_clap_deinit() callconv(.c) void {}

export fn savera_clap_get_factory(factory_id: [*c]const u8) callconv(.c) ?*const anyopaque {
    if (factory_id == null or !std.mem.eql(u8, std.mem.span(factory_id), &c.CLAP_PLUGIN_FACTORY_ID)) return null;
    return &plugin.factory;
}

pub const entry: c.clap_plugin_entry_t = .{
    .clap_version = clap.version,
    .init = savera_clap_init,
    .deinit = savera_clap_deinit,
    .get_factory = savera_clap_get_factory,
};

comptime {
    if (build_options.export_entry) @export(&entry, .{ .name = "clap_entry", .linkage = .strong });
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("build_info.zig");
    _ = @import("clap/midi.zig");
    _ = @import("clap/state.zig");
}

test "entry exposes only Savera's factory" {
    try std.testing.expect(savera_clap_get_factory(&c.CLAP_PLUGIN_FACTORY_ID) != null);
    try std.testing.expect(savera_clap_get_factory("wrong") == null);
}
