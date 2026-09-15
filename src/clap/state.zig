const std = @import("std");
const c = @import("c.zig").c;

pub const magic = "SVRA";
pub const version: u32 = 1;
pub const header_size = magic.len + @sizeOf(u32);

pub const LoadError = error{ BadMagic, UnsupportedVersion, Truncated, StreamFailed };

pub fn save(stream: *const c.clap_ostream_t) bool {
    var header: [header_size]u8 = undefined;
    @memcpy(header[0..magic.len], magic);
    std.mem.writeInt(u32, header[magic.len..][0..4], version, .little);
    const write = stream.write orelse return false;
    return write(stream, &header, header.len) == header.len;
}

pub fn load(stream: *const c.clap_istream_t) LoadError!void {
    var header: [header_size]u8 = undefined;
    const read = stream.read orelse return error.StreamFailed;
    var done: usize = 0;
    while (done < header.len) {
        const n = read(stream, header[done..].ptr, header.len - done);
        if (n == 0) return error.Truncated;
        if (n < 0) return error.StreamFailed;
        done += @intCast(n);
    }
    if (!std.mem.eql(u8, header[0..magic.len], magic)) return error.BadMagic;
    if (std.mem.readInt(u32, header[magic.len..][0..4], .little) > version) return error.UnsupportedVersion;
}

test "state framing constants are permanent" {
    try std.testing.expectEqualStrings("SVRA", magic);
    try std.testing.expectEqual(@as(usize, 8), header_size);
}
