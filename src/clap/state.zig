const std = @import("std");
const c = @import("c.zig").c;

/// Permanent state framing identifier; hosts retain these bytes in projects.
pub const magic = "SVRA";
pub const version: u32 = 1;
pub const header_size = magic.len + @sizeOf(u32);

pub const LoadError = error{ BadMagic, UnsupportedVersion, Truncated, StreamFailed };

pub fn save(stream: *const c.clap_ostream_t) bool {
    var header: [header_size]u8 = undefined;
    @memcpy(header[0..magic.len], magic);
    std.mem.writeInt(u32, header[magic.len..][0..4], version, .little);
    const write = stream.write orelse return false;
    var done: usize = 0;
    while (done < header.len) {
        const n = write(stream, header[done..].ptr, header.len - done);
        if (n <= 0 or n > header.len - done) return false;
        done += @intCast(n);
    }
    return true;
}

pub fn load(stream: *const c.clap_istream_t) LoadError!void {
    var header: [header_size]u8 = undefined;
    const read = stream.read orelse return error.StreamFailed;
    var done: usize = 0;
    while (done < header.len) {
        const n = read(stream, header[done..].ptr, header.len - done);
        if (n == 0) return error.Truncated;
        if (n < 0) return error.StreamFailed;
        if (n > header.len - done) return error.StreamFailed;
        done += @intCast(n);
    }
    if (!std.mem.eql(u8, header[0..magic.len], magic)) return error.BadMagic;
    if (std.mem.readInt(u32, header[magic.len..][0..4], .little) != version) return error.UnsupportedVersion;
}

const TestStream = struct {
    bytes: [16]u8 = [_]u8{0} ** 16,
    position: usize = 0,
    length: usize = 0,
    fn read(stream: [*c]const c.clap_istream_t, buffer: ?*anyopaque, size: u64) callconv(.c) i64 {
        const self: *TestStream = @ptrCast(@alignCast(stream.*.ctx.?));
        const n = @min(@min(size, 2), self.length - self.position);
        const out: [*]u8 = @ptrCast(buffer.?);
        @memcpy(out[0..n], self.bytes[self.position..][0..n]);
        self.position += n;
        return @intCast(n);
    }
    fn write(stream: [*c]const c.clap_ostream_t, buffer: ?*const anyopaque, size: u64) callconv(.c) i64 {
        const self: *TestStream = @ptrCast(@alignCast(stream.*.ctx.?));
        const n = @min(size, 2);
        const input: [*]const u8 = @ptrCast(buffer.?);
        @memcpy(self.bytes[self.position..][0..n], input[0..n]);
        self.position += n;
        self.length = self.position;
        return @intCast(n);
    }
};
test "state round trips partial streams and refuses invalid headers" {
    var data = TestStream{};
    const output = c.clap_ostream_t{ .ctx = &data, .write = TestStream.write };
    const input = c.clap_istream_t{ .ctx = &data, .read = TestStream.read };
    try std.testing.expect(save(&output));
    data.position = 0;
    data.length = 12; // Trailing bytes belong to later payloads.
    try load(&input);
    data.position = 0;
    data.length = 7;
    try std.testing.expectError(error.Truncated, load(&input));
    data.position = 0;
    data.length = 8;
    data.bytes[0] = 'X';
    try std.testing.expectError(error.BadMagic, load(&input));
    data.position = 0;
    data.bytes[0] = 'S';
    data.bytes[4] = 2;
    try std.testing.expectError(error.UnsupportedVersion, load(&input));
    data.position = 0;
    data.bytes[4] = 0;
    try std.testing.expectError(error.UnsupportedVersion, load(&input));
}

test "state framing constants are permanent" {
    try std.testing.expectEqualStrings("SVRA", magic);
    try std.testing.expectEqual(@as(usize, 8), header_size);
}
