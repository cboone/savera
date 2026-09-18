---
applyTo: "**/*.zig,**/*.zig.zon"
---

# Reviewing this project's Zig

For repo-wide conventions, see [`copilot-instructions.md`](copilot-instructions.md) and `AGENTS.md` at the repository root.

The Phase 1 shell uses Zig 0.16.0. These entries are conventions the ADRs already settled, recorded so review does not relitigate them.

- **Nothing under `src/model/` may name the CLAP bindings, a sample offset or a note id.** The CLAP half is enforced mechanically: a test walks that directory from the source root at run time and fails on any mention of `clap/c.zig` or an import resolving to the CLAP bindings. The sample-offset and note-id half has no distinctive import to detect and is held by review, so flag either one appearing under `src/model/`. If a change appears to need a CLAP type or a note id there, the value belongs in `src/engine/` or should be threaded in as a plain argument. See [ADR 0005](../docs/adr/0005-a-pure-model-core-behind-a-seam.md).
- **Fixed-capacity structures on the audio path are not premature optimization.** Nothing reachable from `process()` may allocate, lock, or make a syscall, so a growable container there is a defect rather than a simplification. Capacities are derived in one place with the derivation beside them. See [ADR 0007](../docs/adr/0007-no-allocation-on-the-audio-thread.md).
- **Trust boundaries refuse with a runtime `if`, never `std.debug.assert`.** The shipped CLAP is ReleaseFast, where `assert` is compiled away, so an assert-guarded boundary is unguarded in exactly the build users run. Do not suggest replacing such an `if` with an `assert`. See [ADR 0007](../docs/adr/0007-no-allocation-on-the-audio-thread.md).
- **The solver's `.strict` float mode, `f64` state and fixed iteration count are deliberate.** They keep the residual identical in every optimize mode and the work per sample bounded, which the oracle comparison depends on. Do not suggest `.optimized` float mode, `f32` state, or iterating to a tolerance. See [ADR 0010](../docs/adr/0010-fixed-k-bracketed-newton-solver.md).
- **Flush-to-zero is set through the ARM64 floating-point control register around `process()`**, because `@setFloatMode` does not touch that register. Do not suggest removing the save and restore as redundant with the float mode.
- **An infinite `clap.tail` is any value at or above `INT32_MAX`.** That is the sentinel `clap/ext/tail.h` specifies in the pinned CLAP 1.2.10, which defines no named constant for it. Do not suggest `UINT32_MAX` or a `CLAP_TAIL_INFINITE` constant in its place. See [ADR 0011](../docs/adr/0011-fixed-internal-sample-rate.md).
- **Parameter ids are permanent.** Do not suggest renumbering, compacting, or deriving them from position, even where the enum has gaps. The gaps are deliberate. See [ADR 0008](../docs/adr/0008-parameters-identified-by-stable-clap-id.md).
- **Comptime `@sizeOf` and `@offsetOf` assertions over CLAP structs are not redundant with the translation.** A binding that compiles is not a binding whose layout is right, and the failure mode is a silent misread on the audio thread. See [ADR 0004](../docs/adr/0004-clap-bindings-via-translate-c.md).
- **Vectors are coerced to arrays before indexing.** Zig 0.16 forbids runtime indexing into a vector. See [ADR 0002](../docs/adr/0002-zig-pinned-to-0-16-0.md).
- **There is no line-length limit.** Comments and doc comments are one long line per paragraph.
