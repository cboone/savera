pub const Event = union(enum) {
    note_on: struct { channel: u4, key: u7, velocity: u7 },
    note_off: struct { channel: u4, key: u7, velocity: u7 },
    controller: struct { channel: u4, controller: u7, value: u7 },
    channel_pressure: struct { channel: u4, pressure: u7 },
    pitch_bend: struct { channel: u4, value: u14 },
    rpn: struct { channel: u4, parameter: u14, value: u14 },
};

pub fn parse(bytes: [3]u8) ?Event {
    const status = bytes[0];
    if (status < 0x80 or status >= 0xf0) return null;
    const channel: u4 = @truncate(status);
    const data1: u7 = @truncate(bytes[1]);
    const data2: u7 = @truncate(bytes[2]);
    return switch (status & 0xf0) {
        0x80 => .{ .note_off = .{ .channel = channel, .key = data1, .velocity = data2 } },
        0x90 => if (data2 == 0) .{ .note_off = .{ .channel = channel, .key = data1, .velocity = 0 } } else .{ .note_on = .{ .channel = channel, .key = data1, .velocity = data2 } },
        0xb0 => .{ .controller = .{ .channel = channel, .controller = data1, .value = data2 } },
        0xd0 => .{ .channel_pressure = .{ .channel = channel, .pressure = data1 } },
        0xe0 => .{ .pitch_bend = .{ .channel = channel, .value = (@as(u14, data2) << 7) | data1 } },
        else => null,
    };
}

test "note-on velocity zero is note-off" {
    const std = @import("std");
    try std.testing.expectEqual(Event{ .note_off = .{ .channel = 0, .key = 69, .velocity = 0 } }, parse(.{ 0x90, 69, 0 }).?);
}
