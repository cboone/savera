const std = @import("std");

pub const c = @import("clap_c");
pub const version_major = 1;
pub const version_minor = 2;
pub const version_revision = 10;
pub const version: c.clap_version_t = .{ .major = version_major, .minor = version_minor, .revision = version_revision };

pub const feature = struct {
    pub const instrument = "instrument";
    pub const synthesizer = "synthesizer";
};

pub const note_dialect = struct {
    pub const clap = @as(u32, 1) << 0;
    pub const midi = @as(u32, 1) << 1;
    pub const midi_mpe = @as(u32, 1) << 2;
};

pub const port_type = struct {
    pub const mono = "mono";
    pub const stereo = "stereo";
};

comptime {
    assertLayout(c.clap_plugin_entry_t, .{ "clap_version", "init", "deinit", "get_factory" });
    assertLayout(c.clap_plugin_factory_t, .{ "get_plugin_count", "get_plugin_descriptor", "create_plugin" });
    assertLayout(c.clap_plugin_descriptor_t, .{ "id", "name", "features" });
    assertLayout(c.clap_plugin_t, .{ "desc", "init", "process", "get_extension" });
    assertLayout(c.clap_process_t, .{ "frames_count", "audio_outputs", "in_events" });
    assertLayout(c.clap_audio_buffer_t, .{ "data32", "channel_count", "constant_mask" });
    assertLayout(c.clap_event_header_t, .{ "size", "time", "space_id", "type" });
    assertLayout(c.clap_event_note_t, .{ "header", "note_id", "port_index", "channel", "key", "velocity" });
    assertLayout(c.clap_input_events_t, .{ "ctx", "size", "get" });
    assertLayout(c.clap_output_events_t, .{ "ctx", "try_push" });
    assertLayout(c.clap_plugin_audio_ports_t, .{ "count", "get" });
    assertLayout(c.clap_plugin_note_ports_t, .{ "count", "get" });
    assertLayout(c.clap_plugin_state_t, .{ "save", "load" });
    assertLayout(c.clap_plugin_tail_t, .{"get"});
    assertLayout(c.clap_plugin_latency_t, .{"get"});
    assertLayout(c.clap_host_t, .{ "clap_version", "get_extension" });
    assertLayout(c.clap_host_log_t, .{"log"});
    if (@offsetOf(c.clap_host_t, "clap_version") != 0) @compileError("clap_host_t.clap_version must remain first");
}

fn assertLayout(comptime T: type, comptime fields: anytype) void {
    const info = @typeInfo(T).@"struct";
    if (info.layout != .@"extern") @compileError(@typeName(T) ++ " must retain C layout");
    inline for (fields) |field| {
        if (!@hasField(T, field)) @compileError(@typeName(T) ++ " lost " ++ field);
        _ = @offsetOf(T, field);
    }
}

test "restated CLAP version is pinned" {
    try std.testing.expectEqual(c.CLAP_VERSION.major, version.major);
    try std.testing.expectEqual(c.CLAP_VERSION.minor, version.minor);
    try std.testing.expectEqual(c.CLAP_VERSION.revision, version.revision);
}
