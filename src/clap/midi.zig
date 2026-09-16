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
    if (status < 0x80 or status >= 0xf0 or bytes[1] > 127 or bytes[2] > 127) return null;
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

/// MIDI RPN selection and data entry are independent on each of sixteen channels.
pub const Parser = struct {
    const Channel = struct { msb: u7 = 127, lsb: u7 = 127, data_msb: u7 = 0, data_lsb: u7 = 0 };
    channels: [16]Channel = [_]Channel{.{}} ** 16,
    pub fn decode(self: *Parser, bytes: [3]u8) ?Event {
        const event = parse(bytes) orelse return null;
        switch (event) {
            .controller => |cc| {
                const channel = &self.channels[cc.channel];
                switch (cc.controller) {
                    101 => channel.msb = cc.value,
                    100 => channel.lsb = cc.value,
                    99, 98 => {
                        channel.msb = 127;
                        channel.lsb = 127;
                    },
                    6, 38 => {
                        if (cc.controller == 6) channel.data_msb = cc.value else channel.data_lsb = cc.value;
                        if (channel.msb != 127 or channel.lsb != 127) return .{ .rpn = .{ .channel = cc.channel, .parameter = (@as(u14, channel.msb) << 7) | channel.lsb, .value = (@as(u14, channel.data_msb) << 7) | channel.data_lsb } };
                    },
                    else => {},
                }
            },
            else => {},
        }
        return event;
    }
};

test "RPN data entry, null selection, and channel isolation" {
    const std = @import("std");
    var parser = Parser{};
    _ = parser.decode(.{ 0xb2, 101, 0 });
    _ = parser.decode(.{ 0xb2, 100, 0 });
    try std.testing.expectEqual(Event{ .rpn = .{ .channel = 2, .parameter = 0, .value = 256 } }, parser.decode(.{ 0xb2, 6, 2 }).?);
    try std.testing.expectEqual(Event{ .rpn = .{ .channel = 2, .parameter = 0, .value = 259 } }, parser.decode(.{ 0xb2, 38, 3 }).?);
    try std.testing.expect(parser.decode(.{ 0xb3, 6, 2 }).? == .controller);
    _ = parser.decode(.{ 0xb2, 101, 127 });
    _ = parser.decode(.{ 0xb2, 100, 127 });
    try std.testing.expect(parser.decode(.{ 0xb2, 6, 2 }).? == .controller);
    try std.testing.expect(parse(.{ 0x90, 255, 1 }) == null);
}

test "note-on velocity zero is note-off" {
    const std = @import("std");
    try std.testing.expectEqual(Event{ .note_off = .{ .channel = 0, .key = 69, .velocity = 0 } }, parse(.{ 0x90, 69, 0 }).?);
}
