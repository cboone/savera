const std = @import("std");
const build_info = @import("../build_info.zig");
const clap = @import("c.zig");
const state = @import("state.zig");
const midi = @import("midi.zig");
const c = clap.c;

/// Permanent: hosts persist this identifier in project files.
pub const id = "com.catamountaudio.savera";
/// Permanent input port identifier; hosts retain port routing in projects.
pub const note_input_id: c.clap_id = 0;
/// Permanent stereo output identifier; hosts retain port routing in projects.
pub const audio_output_id: c.clap_id = 0;

const features = [_:null]?[*:0]const u8{ clap.feature.instrument, clap.feature.synthesizer };

pub const descriptor: c.clap_plugin_descriptor_t = .{
    .clap_version = clap.version,
    .id = id,
    .name = "Savera",
    .vendor = "Catamount Audio",
    .url = "https://github.com/cboone/savera",
    .manual_url = "https://github.com/cboone/savera#readme",
    .support_url = "https://github.com/cboone/savera/issues",
    .version = build_info.descriptor_version.ptr,
    .description = "A physically modelled Indian hand harmonium.",
    .features = @ptrCast(&features),
};

pub const factory: c.clap_plugin_factory_t = .{ .get_plugin_count = getPluginCount, .get_plugin_descriptor = getPluginDescriptor, .create_plugin = createPlugin };

// The integration fixture allows sixteen simultaneous keys, without bank fan-out.
const voice_capacity = 16;
/// Throwaway Phase 1 sine fixture; the physical engine replaces these voices.
const Voice = struct { active: bool = false, note_id: i32 = -1, channel: i16 = -1, key: i16 = -1, phase: f32 = 0, increment: f32 = 0 };
const Instance = struct {
    plugin: c.clap_plugin_t,
    host: *const c.clap_host_t,
    sample_rate: f32 = 0,
    max_frames: u32 = 0,
    active: bool = false,
    processing: bool = false,
    voices: [voice_capacity]Voice = [_]Voice{.{}} ** voice_capacity,

    fn from(plugin: [*c]const c.clap_plugin_t) *Instance {
        return @ptrCast(@alignCast(plugin.*.plugin_data.?));
    }
};

fn getPluginCount(factory_ptr: [*c]const c.clap_plugin_factory_t) callconv(.c) u32 {
    _ = factory_ptr;
    return 1;
}
fn getPluginDescriptor(factory_ptr: [*c]const c.clap_plugin_factory_t, index: u32) callconv(.c) [*c]const c.clap_plugin_descriptor_t {
    _ = factory_ptr;
    return if (index == 0) &descriptor else null;
}

fn createPlugin(factory_ptr: [*c]const c.clap_plugin_factory_t, host: [*c]const c.clap_host_t, plugin_id: [*c]const u8) callconv(.c) [*c]const c.clap_plugin_t {
    _ = factory_ptr;
    if (host == null or plugin_id == null or !c.clap_version_is_compatible(host.*.clap_version) or !std.mem.eql(u8, std.mem.span(plugin_id), id)) return null;
    const self = std.heap.c_allocator.create(Instance) catch return null;
    self.* = .{ .plugin = .{ .desc = &descriptor, .plugin_data = self, .init = init, .destroy = destroy, .activate = activate, .deactivate = deactivate, .start_processing = startProcessing, .stop_processing = stopProcessing, .reset = reset, .process = process, .get_extension = getExtension, .on_main_thread = onMainThread }, .host = host };
    return &self.plugin;
}

fn init(plugin: [*c]const c.clap_plugin_t) callconv(.c) bool {
    const self = Instance.from(plugin);
    if (self.host.get_extension) |get| if (get(self.host, &c.CLAP_EXT_LOG)) |raw| {
        const log: *const c.clap_host_log_t = @ptrCast(@alignCast(raw));
        if (log.log) |write| write(self.host, c.CLAP_LOG_INFO, build_info.marker.ptr);
    };
    return true;
}
fn destroy(plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    std.heap.c_allocator.destroy(Instance.from(plugin));
}
fn activate(plugin: [*c]const c.clap_plugin_t, sample_rate: f64, min_frames: u32, max_frames: u32) callconv(.c) bool {
    const self = Instance.from(plugin);
    if (!std.math.isFinite(sample_rate) or sample_rate <= 0 or sample_rate > std.math.floatMax(f32) or max_frames == 0 or max_frames < min_frames) return false;
    self.sample_rate = @floatCast(sample_rate);
    self.max_frames = max_frames;
    self.active = true;
    clear(self);
    return true;
}
fn deactivate(plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    const self = Instance.from(plugin);
    clear(self);
    self.active = false;
}
fn startProcessing(plugin: [*c]const c.clap_plugin_t) callconv(.c) bool {
    const self = Instance.from(plugin);
    if (!self.active) return false;
    self.processing = true;
    return true;
}
fn stopProcessing(plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    Instance.from(plugin).processing = false;
}
fn reset(plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    clear(Instance.from(plugin));
}
fn onMainThread(plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    _ = plugin;
}

fn clear(self: *Instance) void {
    self.voices = [_]Voice{.{}} ** voice_capacity;
}

fn getExtension(plugin: [*c]const c.clap_plugin_t, extension_id: [*c]const u8) callconv(.c) ?*const anyopaque {
    _ = plugin;
    if (extension_id == null) return null;
    const wanted = std.mem.span(extension_id);
    if (std.mem.eql(u8, wanted, &c.CLAP_EXT_AUDIO_PORTS)) return &audio_ports;
    if (std.mem.eql(u8, wanted, &c.CLAP_EXT_NOTE_PORTS)) return &note_ports;
    if (std.mem.eql(u8, wanted, &c.CLAP_EXT_STATE)) return &plugin_state;
    if (std.mem.eql(u8, wanted, &c.CLAP_EXT_TAIL)) return &tail;
    if (std.mem.eql(u8, wanted, &c.CLAP_EXT_LATENCY)) return &latency;
    return null;
}

const audio_ports: c.clap_plugin_audio_ports_t = .{ .count = audioPortCount, .get = audioPortGet };
fn audioPortCount(plugin: [*c]const c.clap_plugin_t, is_input: bool) callconv(.c) u32 {
    _ = plugin;
    return if (is_input) 0 else 1;
}
fn audioPortGet(plugin: [*c]const c.clap_plugin_t, index: u32, is_input: bool, info: [*c]c.clap_audio_port_info_t) callconv(.c) bool {
    _ = plugin;
    if (is_input or index != 0 or info == null) return false;
    info.* = .{ .id = audio_output_id, .name = [_]u8{0} ** 256, .flags = c.CLAP_AUDIO_PORT_IS_MAIN, .channel_count = 2, .port_type = clap.port_type.stereo, .in_place_pair = c.CLAP_INVALID_ID };
    @memcpy(info.*.name[0..6], "Output");
    return true;
}
const note_ports: c.clap_plugin_note_ports_t = .{ .count = notePortCount, .get = notePortGet };
fn notePortCount(plugin: [*c]const c.clap_plugin_t, is_input: bool) callconv(.c) u32 {
    _ = plugin;
    return if (is_input) 1 else 0;
}
fn notePortGet(plugin: [*c]const c.clap_plugin_t, index: u32, is_input: bool, info: [*c]c.clap_note_port_info_t) callconv(.c) bool {
    _ = plugin;
    if (!is_input or index != 0 or info == null) return false;
    info.* = .{ .id = note_input_id, .supported_dialects = clap.note_dialect.clap | clap.note_dialect.midi | clap.note_dialect.midi_mpe, .preferred_dialect = clap.note_dialect.clap, .name = [_]u8{0} ** 256 };
    @memcpy(info.*.name[0..5], "Notes");
    return true;
}
const plugin_state: c.clap_plugin_state_t = .{ .save = stateSave, .load = stateLoad };
fn stateSave(plugin: [*c]const c.clap_plugin_t, stream: [*c]const c.clap_ostream_t) callconv(.c) bool {
    _ = plugin;
    return stream != null and state.save(stream);
}
fn stateLoad(plugin: [*c]const c.clap_plugin_t, stream: [*c]const c.clap_istream_t) callconv(.c) bool {
    _ = plugin;
    if (stream == null) return false;
    state.load(stream) catch return false;
    return true;
}
const tail: c.clap_plugin_tail_t = .{ .get = zero };
const latency: c.clap_plugin_latency_t = .{ .get = zero };
fn zero(plugin: [*c]const c.clap_plugin_t) callconv(.c) u32 {
    _ = plugin;
    return 0;
}

fn process(plugin: [*c]const c.clap_plugin_t, process_ctx: [*c]const c.clap_process_t) callconv(.c) c.clap_process_status {
    const self = Instance.from(plugin);
    if (process_ctx == null or !self.active or !self.processing or process_ctx.*.frames_count > self.max_frames) return c.CLAP_PROCESS_ERROR;
    const ctx = process_ctx.*;
    if (ctx.audio_outputs == null or ctx.audio_outputs_count == 0) return c.CLAP_PROCESS_CONTINUE;
    const output = &ctx.audio_outputs[0];
    if (output.data32 == null or output.channel_count < 2) return c.CLAP_PROCESS_ERROR;
    const events = ctx.in_events;
    const event_count: u32 = if (events != null) events.*.size.?(events) else 0;
    var next_index: u32 = 0;
    // The host delivers input events sorted by time, so one pass reads each event once and holds it until its frame.
    var pending = nextEvent(events, event_count, &next_index);
    var frame: u32 = 0;
    while (frame < ctx.frames_count) : (frame += 1) {
        while (pending) |header| : (pending = nextEvent(events, event_count, &next_index)) {
            if (header.time > frame) break;
            handleEvent(self, header);
        }
        var sample: f32 = 0;
        for (&self.voices) |*voice| if (voice.active) {
            sample += @sin(voice.phase);
            voice.phase += voice.increment;
            if (voice.phase > 2 * std.math.pi) voice.phase -= 2 * std.math.pi;
        };
        output.data32[0][frame] = sample * 0.1;
        output.data32[1][frame] = sample * 0.1;
    }
    output.constant_mask = 0;
    return c.CLAP_PROCESS_CONTINUE;
}

fn nextEvent(events: [*c]const c.clap_input_events_t, count: u32, index: *u32) ?*const c.clap_event_header_t {
    while (index.* < count) {
        const header = events.*.get.?(events, index.*);
        index.* += 1;
        if (header != null) return header;
    }
    return null;
}
fn handleEvent(self: *Instance, header: [*c]const c.clap_event_header_t) void {
    if (header.*.space_id != c.CLAP_CORE_EVENT_SPACE_ID) return;
    if (header.*.type == c.CLAP_EVENT_NOTE_ON or header.*.type == c.CLAP_EVENT_NOTE_OFF or header.*.type == c.CLAP_EVENT_NOTE_CHOKE) {
        if (header.*.size < @sizeOf(c.clap_event_note_t)) return;
        const note: *const c.clap_event_note_t = @ptrCast(@alignCast(header));
        // ADR 0023's (port, channel, key, note_id) address: the only note port has index 0, and -1 addresses every port.
        if (note.port_index != 0 and note.port_index != -1) return;
        if (header.*.type == c.CLAP_EVENT_NOTE_ON) noteOn(self, note.note_id, note.channel, note.key) else noteOff(self, note.note_id, note.channel, note.key);
    } else if (header.*.type == c.CLAP_EVENT_MIDI) {
        if (header.*.size < @sizeOf(c.clap_event_midi_t)) return;
        const event: *const c.clap_event_midi_t = @ptrCast(@alignCast(header));
        if (event.port_index != 0) return;
        if (midi.parse(event.data)) |decoded| switch (decoded) {
            .note_on => |note| noteOn(self, -1, note.channel, note.key),
            .note_off => |note| noteOff(self, -1, note.channel, note.key),
            else => {},
        };
    }
}
fn noteOn(self: *Instance, note_id: i32, channel: i16, key: i16) void {
    if (key < 0 or key > 127) return;
    for (&self.voices) |*voice| if (!voice.active) {
        const semitones: f32 = @floatFromInt(key - 69);
        voice.* = .{ .active = true, .note_id = note_id, .channel = channel, .key = key, .increment = 2 * std.math.pi * 440 * std.math.pow(f32, 2, semitones / 12) / self.sample_rate };
        return;
    };
}
/// A -1 in the event's address is a wildcard, so a note-off without a note id releases every voice on its channel and key.
fn noteOff(self: *Instance, note_id: i32, channel: i16, key: i16) void {
    for (&self.voices) |*voice| {
        if (voice.active and (note_id == -1 or voice.note_id == note_id) and (channel == -1 or voice.channel == channel) and (key == -1 or voice.key == key)) voice.active = false;
    }
}

test "the permanent descriptor begins with instrument" {
    try std.testing.expectEqualStrings(clap.feature.instrument, std.mem.span(descriptor.features[0].?));
}

fn testNote(kind: u16, time: u32, note_id: i32, port_index: i16, key: i16) c.clap_event_note_t {
    return .{ .header = .{ .size = @sizeOf(c.clap_event_note_t), .time = time, .space_id = c.CLAP_CORE_EVENT_SPACE_ID, .type = kind, .flags = 0 }, .note_id = note_id, .port_index = port_index, .channel = 0, .key = key, .velocity = 1 };
}
fn activeVoices(self: *const Instance) usize {
    var count: usize = 0;
    for (self.voices) |voice| count += @intFromBool(voice.active);
    return count;
}

test "a note-off with a note id releases only that voice, and one without releases the key" {
    var self = Instance{ .plugin = undefined, .host = undefined, .sample_rate = 48000 };
    for ([_]i32{ 1, 2, 3 }) |note_id| handleEvent(&self, &testNote(c.CLAP_EVENT_NOTE_ON, 0, note_id, 0, 60).header);
    handleEvent(&self, &testNote(c.CLAP_EVENT_NOTE_OFF, 0, 1, 0, 60).header);
    try std.testing.expectEqual(@as(usize, 2), activeVoices(&self));
    handleEvent(&self, &testNote(c.CLAP_EVENT_NOTE_OFF, 0, -1, -1, 60).header);
    try std.testing.expectEqual(@as(usize, 0), activeVoices(&self));
}

test "note events addressed to another note port are ignored" {
    var self = Instance{ .plugin = undefined, .host = undefined, .sample_rate = 48000 };
    handleEvent(&self, &testNote(c.CLAP_EVENT_NOTE_ON, 0, -1, 1, 60).header);
    try std.testing.expectEqual(@as(usize, 0), activeVoices(&self));
    handleEvent(&self, &testNote(c.CLAP_EVENT_NOTE_ON, 0, -1, 0, 60).header);
    handleEvent(&self, &testNote(c.CLAP_EVENT_NOTE_OFF, 0, -1, 1, 60).header);
    try std.testing.expectEqual(@as(usize, 1), activeVoices(&self));
}

test "one pass over the sorted event list reads each event once and applies it at its own frame" {
    const Script = struct {
        headers: []const *const c.clap_event_header_t,
        gets: u32 = 0,
        fn size(list: [*c]const c.clap_input_events_t) callconv(.c) u32 {
            const script: *const @This() = @ptrCast(@alignCast(list.*.ctx.?));
            return @intCast(script.headers.len);
        }
        fn get(list: [*c]const c.clap_input_events_t, index: u32) callconv(.c) [*c]const c.clap_event_header_t {
            const script: *@This() = @ptrCast(@alignCast(list.*.ctx.?));
            script.gets += 1;
            return if (index < script.headers.len) script.headers[index] else null;
        }
    };
    var host = std.mem.zeroes(c.clap_host_t);
    host.clap_version = c.CLAP_VERSION;
    const instance = createPlugin(&factory, &host, id);
    try std.testing.expect(instance != null);
    defer destroy(instance);
    try std.testing.expect(activate(instance, 48000, 1, 8));
    try std.testing.expect(startProcessing(instance));
    const on = testNote(c.CLAP_EVENT_NOTE_ON, 4, -1, 0, 69);
    const off = testNote(c.CLAP_EVENT_NOTE_OFF, 6, -1, 0, 69);
    var script = Script{ .headers = &.{ &on.header, &off.header } };
    const list = c.clap_input_events_t{ .ctx = &script, .size = Script.size, .get = Script.get };
    var left = [_]f32{1} ** 8;
    var right = [_]f32{1} ** 8;
    var channels = [_][*c]f32{ &left, &right };
    var audio = std.mem.zeroes(c.clap_audio_buffer_t);
    audio.data32 = &channels;
    audio.channel_count = 2;
    var ctx = std.mem.zeroes(c.clap_process_t);
    ctx.frames_count = 8;
    ctx.audio_outputs = &audio;
    ctx.audio_outputs_count = 1;
    ctx.in_events = &list;
    try std.testing.expectEqual(c.CLAP_PROCESS_CONTINUE, process(instance, &ctx));
    // The voice starts at phase zero on frame 4 and stops before frame 6, so frame 5 alone sounds.
    for (left, 0..) |sample, frame| try std.testing.expectEqual(frame == 5, sample != 0);
    try std.testing.expectEqual(@as(u32, @intCast(script.headers.len)), script.gets);
}
