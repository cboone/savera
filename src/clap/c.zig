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
    // CLAP 1.2.10's 64-bit C ABI. Both supported macOS and Linux test targets use it.
    assertAbi(c.clap_plugin_entry_t, 40, .{ .clap_version = 0, .init = 16, .deinit = 24, .get_factory = 32 });
    assertAbi(c.clap_plugin_factory_t, 24, .{ .get_plugin_count = 0, .get_plugin_descriptor = 8, .create_plugin = 16 });
    assertAbi(c.clap_plugin_descriptor_t, 88, .{ .clap_version = 0, .id = 16, .name = 24, .vendor = 32, .url = 40, .manual_url = 48, .support_url = 56, .version = 64, .description = 72, .features = 80 });
    assertAbi(c.clap_plugin_t, 96, .{ .desc = 0, .plugin_data = 8, .init = 16, .destroy = 24, .activate = 32, .deactivate = 40, .start_processing = 48, .stop_processing = 56, .reset = 64, .process = 72, .get_extension = 80, .on_main_thread = 88 });
    assertAbi(c.clap_host_t, 88, .{ .clap_version = 0, .host_data = 16, .name = 24, .vendor = 32, .url = 40, .version = 48, .get_extension = 56, .request_restart = 64, .request_process = 72, .request_callback = 80 });
    assertAbi(c.clap_process_t, 64, .{ .steady_time = 0, .frames_count = 8, .transport = 16, .audio_inputs = 24, .audio_outputs = 32, .audio_inputs_count = 40, .audio_outputs_count = 44, .in_events = 48, .out_events = 56 });
    assertAbi(c.clap_audio_buffer_t, 32, .{ .data32 = 0, .data64 = 8, .channel_count = 16, .latency = 20, .constant_mask = 24 });
    assertAbi(c.clap_event_header_t, 16, .{ .size = 0, .time = 4, .space_id = 8, .type = 10, .flags = 12 });
    assertAbi(c.clap_event_note_t, 40, .{ .header = 0, .note_id = 16, .port_index = 20, .channel = 22, .key = 24, .velocity = 32 });
    assertAbi(c.clap_event_midi_t, 24, .{ .header = 0, .port_index = 16, .data = 18 });
    assertAbi(c.clap_input_events_t, 24, .{ .ctx = 0, .size = 8, .get = 16 });
    assertAbi(c.clap_output_events_t, 16, .{ .ctx = 0, .try_push = 8 });
    assertAbi(c.clap_audio_port_info_t, 288, .{ .id = 0, .name = 4, .flags = 260, .channel_count = 264, .port_type = 272, .in_place_pair = 280 });
    assertAbi(c.clap_note_port_info_t, 268, .{ .id = 0, .supported_dialects = 4, .preferred_dialect = 8, .name = 12 });
    assertAbi(c.clap_plugin_audio_ports_t, 16, .{ .count = 0, .get = 8 });
    assertAbi(c.clap_plugin_note_ports_t, 16, .{ .count = 0, .get = 8 });
    assertAbi(c.clap_plugin_state_t, 16, .{ .save = 0, .load = 8 });
    assertAbi(c.clap_istream_t, 16, .{ .ctx = 0, .read = 8 });
    assertAbi(c.clap_ostream_t, 16, .{ .ctx = 0, .write = 8 });
    assertAbi(c.clap_plugin_tail_t, 8, .{ .get = 0 });
    assertAbi(c.clap_plugin_latency_t, 8, .{ .get = 0 });
    assertAbi(c.clap_host_log_t, 8, .{ .log = 0 });
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

fn assertAbi(comptime T: type, comptime size: usize, comptime offsets: anytype) void {
    if (@sizeOf(T) != size) @compileError(@typeName(T) ++ " ABI size mismatch");
    inline for (std.meta.fields(@TypeOf(offsets))) |field| {
        if (@offsetOf(T, field.name) != @field(offsets, field.name)) @compileError(@typeName(T) ++ "." ++ field.name ++ " ABI offset mismatch");
    }
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
