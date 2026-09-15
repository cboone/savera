const build_options = @import("build_options");

pub const version: [:0]const u8 = build_options.version;
pub const branch: [:0]const u8 = build_options.git_branch;
pub const commit: [:0]const u8 = build_options.git_commit;
pub const dirty: bool = build_options.git_dirty;
pub const marker_prefix = "savera-build: ";
pub const marker: [:0]const u8 = marker_prefix ++ "branch=" ++ branch ++ " commit=" ++ commit ++ " dirty=" ++ (if (dirty) "true" else "false") ++ " version=" ++ version;
pub const descriptor_version: [:0]const u8 = version;

test "marker stays recognizable to the extractor" {
    const std = @import("std");
    try std.testing.expect(std.mem.startsWith(u8, marker, marker_prefix));
}
