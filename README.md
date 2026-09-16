# savera

A modulatable synthesizer built on a physical model of the Indian hand harmonium (peti), for macOS (CLAP and AUv2).

Savera is Hindi and Urdu for "dawn", said sa-VEH-ra.

## Status

Early development, with a buildable integration shell. `zig build` assembles `zig-out/Savera.clap`; `zig build smoke` exercises its host boundary. No release has been cut.

What it is meant to become: a peti whose reed, air supply and wooden box are modelled from the free-reed acoustics literature and calibrated against recordings, so it sounds like a harmonium rather than an organ patch. Loudness lives in continuous bellows pressure from an expression pedal, a breath controller, aftertouch or a synthesized pumping generator. Chords sag because every reed draws on one shared air supply. Keys are valves, so pressing one partway brings a note in quieter, slower and slightly flat. Past the acoustic instrument, every physical quantity is modulatable, and the model can glide in pitch and play the 22 shruti, which no real free reed can do.

## Roadmap

Eleven phases. [The build plan](docs/plans/2026-09-13-savera-build-plan.md) holds the reasoning, the sequencing and the exit criteria for each, and [the brainstorm](docs/design/peti-physical-model-brainstorm.md) is the background it came from. Issues are filed one phase at a time, so a phase marked planned deliberately has none yet.

| Phase | Scope                                                                                     | Status   |
| ----- | ----------------------------------------------------------------------------------------- | -------- |
| 0     | Repository foundation: agent config, CI, lint configuration, ADRs, notes                  | Complete |
| 1     | The shell in both formats, with a placeholder sine voice: loads in Logic as an instrument | Active   |
| 2     | The single reed: the Python harness, the Zig model, the oracle                            | Planned  |
| 3     | Parameters, state, the modulation flags and CC learn                                      | Planned  |
| 4     | The engine: voices, block splitting, the resampler, latency and tail                      | Planned  |
| 5     | The air path: reservoir, pallets, drones, the male bank across the keyboard               | Planned  |
| 6     | The sound: cabinet filter, pump generator, noise, calibration, presets                    | Planned  |
| 7     | Release v0.1.0: a signed, notarized installer                                             | Planned  |
| 8     | The full instrument, v0.2.0: three banks, coupler, scale changer, tremolo                 | Planned  |
| 9     | Beyond the acoustic instrument, v0.3.0: modulators, glides, tuning tables                 | Planned  |
| 10    | Optional, each gated by a measurement: modal reed, hybrid engine, MTS-ESP, GUI            | Deferred |

Phases 4, 5 and 6 together are the first playable instrument, and Phase 7 ships it.

## Requirements

Planned, for the first release:

- macOS 11 or later on Apple Silicon. Intel Macs, Windows and Linux are out of scope by decision ([ADR 0001](docs/adr/0001-macos-on-apple-silicon-only.md)).
- A host: Logic Pro, which loads the Audio Unit as a software instrument, or REAPER or Bitwig Studio, which load the CLAP.
- Something to play the bellows with: an expression pedal, a breath controller, aftertouch, or the built-in pump generator.

## Building

Use `zig build` for the direct CLAP, `zig build test` for unit tests, `zig build smoke` for the host-boundary fixture, and `zig build audio-unit` for the CMake projection. The installer remains a Phase 7 release artifact.

The shell needs Zig 0.16.0, CMake and clap-validator 0.4.1 on an Apple Silicon Mac. `zig build test-safe` and `zig build test-release` run both release test modes; `zig build validate` validates the direct CLAP. `zig build --release=fast install-plugins` builds and copies both formats into the user plugin folders and reports installed hashes and provenance. The default signature is ad-hoc; release signing reads `SAVERA_SIGNING_IDENTITY` from the environment.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), and [AGENTS.md](AGENTS.md) for what is settled and what is permanent.

## License

[MIT](LICENSE)
