const std = @import("std");
const zon = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .os_version_min = .{ .semver = .{ .major = 11, .minor = 0, .patch = 0 } } } });
    const optimize = b.standardOptimizeOption(.{});
    const provenance = gitProvenance(b);
    const core = module(b, target, optimize, provenance, false);

    const impl = b.addObject(.{ .name = "savera_impl", .root_module = core });
    const install_impl = b.addInstallFileWithDir(impl.getEmittedBin(), .{ .custom = "lib" }, "savera_impl.o");
    b.step("impl", "Build Savera's wrapper object into the requested prefix").dependOn(&install_impl.step);

    const plugin = b.addLibrary(.{ .name = "Savera", .linkage = .dynamic, .root_module = module(b, target, optimize, provenance, true) });
    const binary = b.addInstallFileWithDir(plugin.getEmittedBin(), .{ .custom = "Savera.clap/Contents/MacOS" }, "Savera");
    const plist = b.addInstallFileWithDir(b.path("macos/Info.plist"), .{ .custom = "Savera.clap/Contents" }, "Info.plist");
    b.getInstallStep().dependOn(&binary.step);
    b.getInstallStep().dependOn(&plist.step);
    if (target.result.os.tag == .macos) {
        const remove_signature = b.addSystemCommand(&.{ "/usr/bin/codesign", "--remove-signature" });
        remove_signature.addArg(b.getInstallPath(.prefix, "Savera.clap"));
        remove_signature.step.dependOn(&binary.step);
        remove_signature.step.dependOn(&plist.step);
        const identity = b.graph.environ_map.get("SAVERA_SIGNING_IDENTITY") orelse "-";
        const sign = b.addSystemCommand(&.{ "/usr/bin/codesign", "--sign", if (identity.len == 0) "-" else identity });
        if (identity.len != 0 and !std.mem.eql(u8, identity, "-")) sign.addArgs(&.{ "--timestamp", "--options", "runtime" });
        sign.addArg(b.getInstallPath(.prefix, "Savera.clap"));
        sign.step.dependOn(&binary.step);
        sign.step.dependOn(&plist.step);
        sign.step.dependOn(&remove_signature.step);
        b.getInstallStep().dependOn(&sign.step);
    }

    addTest(b, target, optimize, provenance, "test", "Run unit tests");
    addTest(b, target, .ReleaseSafe, provenance, "test-safe", "Run unit tests in ReleaseSafe");
    addTest(b, target, .ReleaseFast, provenance, "test-release", "Run unit tests in ReleaseFast");
    const smoke = b.addExecutable(.{ .name = "savera-smoke", .root_module = moduleWithRoot(b, target, optimize, provenance, "src/smoke.zig", false) });
    const run_smoke = b.addRunArtifact(smoke);
    b.step("smoke", "Run the CLAP host smoke harness").dependOn(&run_smoke.step);

    if (target.result.os.tag != .macos) return;
    const validate = b.addSystemCommand(&.{ "clap-validator", "validate" });
    validate.addArg(b.getInstallPath(.prefix, "Savera.clap"));
    validate.step.dependOn(b.getInstallStep());
    b.step("validate", "Validate the direct CLAP").dependOn(&validate.step);
    const audio_unit = b.addSystemCommand(&.{"./scripts/build-audio-unit"});
    audio_unit.stdio = .inherit;
    b.step("audio-unit", "Build Savera.component through CMake").dependOn(&audio_unit.step);
    const install_plugins = b.addSystemCommand(&.{"./scripts/install-plugins"});
    install_plugins.stdio = .inherit;
    install_plugins.step.dependOn(b.getInstallStep());
    install_plugins.step.dependOn(&audio_unit.step);
    b.step("install-plugins", "Build and install CLAP and Audio Unit bundles").dependOn(&install_plugins.step);
}

fn addTest(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, provenance: Provenance, name: []const u8, description: []const u8) void {
    const tests = b.addTest(.{ .root_module = module(b, target, optimize, provenance, false) });
    const run = b.addRunArtifact(tests);
    b.step(name, description).dependOn(&run.step);
}

fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, provenance: Provenance, export_entry: bool) *std.Build.Module {
    return moduleWithRoot(b, target, optimize, provenance, "src/main.zig", export_entry);
}

fn moduleWithRoot(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, provenance: Provenance, root: []const u8, export_entry: bool) *std.Build.Module {
    const options = b.addOptions();
    options.addOption(bool, "export_entry", export_entry);
    options.addOption([:0]const u8, "version", zon.version);
    options.addOption([:0]const u8, "git_branch", provenance.branch);
    options.addOption([:0]const u8, "git_commit", provenance.commit);
    options.addOption(bool, "git_dirty", provenance.dirty);
    const result = b.createModule(.{ .root_source_file = b.path(root), .target = target, .optimize = optimize });
    result.addImport("build_options", options.createModule());
    result.addImport("clap_c", translateClap(b, target, optimize));
    result.addAnonymousImport("provenance_script", .{ .root_source_file = b.path("scripts/read-provenance") });
    return result;
}

fn translateClap(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const dependency = b.dependency("clap", .{});
    const preprocess = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-E", "-P" });
    preprocess.addPrefixedDirectoryArg("-I", dependency.path("include"));
    preprocess.addFileArg(b.path("src/clap/clap_all.h"));
    preprocess.addArg("-o");
    const header = preprocess.addOutputFileArg("clap_preprocessed.h");
    return b.addTranslateC(.{ .root_source_file = header, .target = target, .optimize = optimize }).createModule();
}

const Provenance = struct { branch: [:0]const u8, commit: [:0]const u8, dirty: bool };
fn gitProvenance(b: *std.Build) Provenance {
    const root = b.build_root.path orelse return .{ .branch = "unknown", .commit = "unknown", .dirty = false };
    const branch = gitOutput(b, root, &.{ "rev-parse", "--abbrev-ref", "HEAD" }) orelse return .{ .branch = "unknown", .commit = "unknown", .dirty = false };
    const commit = gitOutput(b, root, &.{ "rev-parse", "--short", "HEAD" }) orelse return .{ .branch = "unknown", .commit = "unknown", .dirty = false };
    const status = gitOutput(b, root, &.{ "status", "--porcelain" }) orelse "";
    return .{ .branch = if (std.mem.eql(u8, branch, "HEAD")) "detached" else branch, .commit = commit, .dirty = status.len != 0 };
}
fn gitOutput(b: *std.Build, root: []const u8, args: []const []const u8) ?[:0]const u8 {
    const argv = b.allocator.alloc([]const u8, args.len + 3) catch return null;
    argv[0] = "/usr/bin/git";
    argv[1] = "-C";
    argv[2] = root;
    @memcpy(argv[3..], args);
    var code: u8 = undefined;
    const output = b.runAllowFail(argv, &code, .ignore) catch return null;
    return b.allocator.dupeZ(u8, std.mem.trim(u8, output, " \t\r\n")) catch null;
}
