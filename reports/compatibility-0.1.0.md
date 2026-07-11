# Compatibility report — 0.1.0

- Godot: 4.6.1 stable, macOS arm64
- godot-cpp: `ba0edfed90512ec64aba51d4295a3e7e30112f86`, API profile 4.6
- Airwindohhs: `ab05f63e38f4d93400322f7e662ec46a24fc81fd`
- Airwindows source: `781eaee378303c7dc4d9edcaabb086cf160ff5df`
- Compatible and registered: 495
- Excluded: 0
- Offline renders: 27,016
- Fixtures: silence, impulse, deterministic noise, two-tone musical input
- Sample rates: 44.1, 48, and 96 kHz
- Callback sizes: 1, 17, 64, and 257 frames
- Parameter coverage: defaults plus each declared minimum and maximum
- Rejections: NaN, Inf, and absolute output above `1e12`

## Special handling

- `amp_sims.chimeyguitar2.compres` is limited to `0.0–0.95`; higher values approach an upstream singularity and produce non-finite output.
- `utility.softclock.count` and `utility.softclock2.count` are limited to `0.05–1.0`; a zero/near-zero count is undefined and produces non-finite output.

The bounds are generated into the Godot property hints and enforced by resource setters. They are recorded in `config/parameter_overrides.json`. No other catalog-specific handling was required.
