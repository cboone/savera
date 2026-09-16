const std = @import("std");
const plugin = @import("clap/plugin.zig");
const boundary = @import("main.zig");
const c = @import("clap/c.zig").c;

fn extension(host: [*c]const c.clap_host_t, id: [*c]const u8) callconv(.c) ?*const anyopaque {
    _ = host;
    _ = id;
    return null;
}
const Events = struct {
    header: *const c.clap_event_header_t,
    enabled: bool = true,
    fn size(list: [*c]const c.clap_input_events_t) callconv(.c) u32 {
        const self: *const Events = @ptrCast(@alignCast(list.*.ctx.?));
        return if (self.enabled) 1 else 0;
    }
    fn get(list: [*c]const c.clap_input_events_t, index: u32) callconv(.c) [*c]const c.clap_event_header_t {
        const self: *const Events = @ptrCast(@alignCast(list.*.ctx.?));
        return if (self.enabled and index == 0) self.header else null;
    }
};
pub fn check() !void {
    var host = std.mem.zeroes(c.clap_host_t);
    host.clap_version = c.CLAP_VERSION;
    host.name = "Savera smoke";
    host.vendor = "Catamount Audio";
    host.url = "https://github.com/cboone/savera";
    host.version = "0";
    host.get_extension = extension;
    if (!boundary.entry.init.?(null)) return error.EntryInit;
    defer boundary.entry.deinit.?();
    const instance = plugin.factory.create_plugin.?(&plugin.factory, &host, plugin.id);
    if (instance == null) return error.Create;
    defer instance.*.destroy.?(instance);
    if (!instance.*.init.?(instance)) return error.Init;
    if (!instance.*.activate.?(instance, 48000, 1, 256)) return error.Activate;
    defer instance.*.deactivate.?(instance);
    if (!instance.*.start_processing.?(instance)) return error.Start;
    defer instance.*.stop_processing.?(instance);
    var left: [256]f32 = undefined;
    var right: [256]f32 = undefined;
    var channels = [_][*c]f32{ &left, &right };
    var audio = std.mem.zeroes(c.clap_audio_buffer_t);
    audio.data32 = &channels;
    audio.channel_count = 2;
    var note = std.mem.zeroes(c.clap_event_note_t);
    note.header = .{ .size = @sizeOf(c.clap_event_note_t), .time = 0, .space_id = 0, .type = c.CLAP_EVENT_NOTE_ON, .flags = 0 };
    note.note_id = -1;
    note.key = 69;
    note.velocity = 1;
    var events = Events{ .header = &note.header };
    var list = c.clap_input_events_t{ .ctx = &events, .size = Events.size, .get = Events.get };
    var ctx = std.mem.zeroes(c.clap_process_t);
    ctx.frames_count = 256;
    ctx.audio_outputs = &audio;
    ctx.audio_outputs_count = 1;
    ctx.in_events = &list;
    try render(instance, &ctx, &left, &right, true);
    note.header.type = c.CLAP_EVENT_NOTE_OFF;
    try render(instance, &ctx, &left, &right, false);
    var raw = std.mem.zeroes(c.clap_event_midi_t);
    raw.header = .{ .size = @sizeOf(c.clap_event_midi_t), .time = 0, .space_id = 0, .type = c.CLAP_EVENT_MIDI, .flags = 0 };
    raw.data = .{ 0x91, 69, 100 };
    events.header = &raw.header;
    try render(instance, &ctx, &left, &right, true);
    raw.data[2] = 0;
    try render(instance, &ctx, &left, &right, false);
    raw.data[2] = 100;
    try render(instance, &ctx, &left, &right, true);
    events.enabled = false;
    instance.*.reset.?(instance);
    try render(instance, &ctx, &left, &right, false);
}
fn render(instance: [*c]const c.clap_plugin_t, ctx: *const c.clap_process_t, left: []const f32, right: []const f32, sounding: bool) !void {
    if (instance.*.process.?(instance, ctx) == c.CLAP_PROCESS_ERROR) return error.Process;
    var energy: f32 = 0;
    for (left, right) |l, r| {
        if (!std.math.isFinite(l) or !std.math.isFinite(r)) return error.NonFinite;
        if (l != r) return error.StereoMismatch;
        energy += @abs(l);
    }
    if (sounding and energy <= 0) return error.SilentNote;
    if (!sounding and energy != 0) return error.ReleaseNotSilent;
}

pub fn main(init: std.process.Init.Minimal) u8 {
    if (init.args.vector.len != 1) {
        std.debug.print("usage: savera-smoke\n", .{});
        return 2;
    }
    check() catch |err| {
        std.debug.print("savera smoke: FAIL {s}\n", .{@errorName(err)});
        return 1;
    };
    std.debug.print("savera smoke: PASS CLAP/MIDI notes, finite dual-mono output, release and reset silence\n", .{});
    return 0;
}
