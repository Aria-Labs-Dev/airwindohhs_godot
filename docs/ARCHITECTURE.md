# Architecture

## Godot ownership

Godot owns the platform audio device, `AudioDriver`, `AudioServer`, bus layout, routing, and final mix. Each generated resource behaves as a peer `AudioEffect`; no project bus is created, replaced, reordered, or implicitly populated by the addon.

The repository stores the extension descriptor as an inert `.gdextension.in` template. CMake copies it to the active `.gdextension` name only after the matching shared library links. This prevents an unbuilt checkout from activating a descriptor whose missing macOS library makes Godot 4.6.1 abort inside `NSBundle`.

`AirwindohhsAudioEffect::_instantiate()` constructs a prepared processor at the active mix rate outside `_process`. `AirwindohhsAudioEffectInstance::_process()` performs only bounded atomic loads, normalized parameter writes, fixed-size deinterleave/process/interleave chunks, and the upstream DSP call. It does not allocate, lock, log, perform I/O, inspect the scene tree, or call Godot services.

## Generated catalog

`tools/generate_catalog.py` scans every generated Airwindohhs header and emits:

- a category-prefixed Godot resource class for each compatible effect;
- sixteen compilation/registration shards;
- sixteen standalone validation shards;
- CMake source lists;
- a machine-readable catalog containing provenance, upstream parameter IDs, ranges, and exclusions.

All effects share the same adapter implementation. Per-effect source is limited to the type binding, metadata, registration, and any reviewed parameter bounds.

## Parameter handoff

Resources and instances share a fixed-capacity `ParameterState`. The game/control thread stores normalized floats in lock-free atomics. The audio callback loads one snapshot per block and applies it before processing. The state is allocated and initialized before the instance is published; its size and metadata do not change during processing.

The initial contract intentionally provides block-boundary automation.