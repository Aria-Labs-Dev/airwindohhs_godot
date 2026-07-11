# Working in airwindohhs_godot

This public MIT-licensed repository exposes clean upstream `airwindohhs` headers as ordinary Godot 4.6+ bus effects.

- Keep the addon independent of AriaEngine and other audio extensions.
- Godot owns the audio device, bus layout, routing, and final mix.
- Generate effect resources, registration, and catalog metadata; do not hand-maintain per-effect wrappers.
- Track the latest default branch of `isabelgk/airwindohhs`. Record the resolved commit in generated provenance without making it a permanent update pin.
- Never copy Vroom's Unreal-specific Airwindohhs header edits or wrapper classes.
- Do not allocate, lock, log, call the scene tree, or make arbitrary Godot calls inside `_process`.
- Keep callback work bounded for arbitrary frame counts and validate NaN/Inf, silence, impulse, noise, musical input, parameters, and callback sizes.
- Add exclusions only with a machine-readable reason and regression evidence.

## Red/green TDD contract

- Begin behavior changes and bug fixes with a test that fails for the expected reason.
- Make the smallest production-code change needed to reach green, then refactor with the full suite green.
- Treat established tests and render baselines as accepted behavioral contracts.
- When an established test turns red, change production code by default. Do not weaken, delete, disable, or rewrite the test or baseline merely to recover green.
- If a test or baseline appears wrong, obsolete, flaky, or incompatible with an intentional contract change, stop and surface the evidence to the human developer before editing it.
