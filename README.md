# Airwindohhs for Godot

An MIT-licensed GDExtension exposing the complete compatible [Airwindohhs](https://github.com/jinpavg/airwindohhs) catalog as native `AudioEffect` resources for Godot 4.6 and later.

The current generated catalog contains 495 effects in upstream categories. 

## Architecture

- One generated `AudioEffect` resource class per compatible effect, prefixed and grouped by category—for example `AirwindohhsDynamicsButterComp`.
- One shared `AudioEffectInstance` implementation and templated processor adapter.
- Inspector properties generated from upstream normalized parameter names and defaults.
- Stable IDs such as `airwindohhs.dynamics.buttercomp.compress` available through `get_parameter_ids()`.
- Lock-free atomic parameter snapshots shared by resources and active instances.
- Fixed 256-frame planar scratch chunks inside `_process`, supporting arbitrary callback sizes without callback allocation or locks.
- Godot retains ownership of the audio device, buses, routing, and final mix.

The addon never creates, replaces, or reorders an `AudioBusLayout`, and it never inserts itself on Master. See [architecture](docs/ARCHITECTURE.md).

## Build

Place `airwindohhs_godot` and `airwindohhs` beside one another, then provide a Godot 4.6-capable `godot-cpp` checkout:

```sh
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Debug \
  -DAIRWINDOHHS_GODOT_GODOT_CPP_PATH=/path/to/godot-cpp \
  -DAIRWINDOHHS_GODOT_GODOT_EXECUTABLE=/path/to/Godot
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Without an existing checkout, CMake fetches pinned `godot-cpp` and the latest `jinpavg/airwindohhs` default branch. `godot-cpp` is pinned at `ba0edfed90512ec64aba51d4295a3e7e30112f86` and generated against the 4.6 API. Airwindohhs intentionally tracks latest; generated and release manifests record the resolved commit used for each build.

The development library is written to `demo/addons/airwindohhs_godot/bin/`. Open `demo/project.godot` as the shared testing ground for this extension and future AriaEngine work.

The active `.gdextension` descriptor is generated only after the shared library links successfully. An unbuilt checkout therefore opens safely instead of pointing Godot's macOS loader at a missing binary. Build the `airwindohhs_godot` target before expecting the effect classes to appear.

## Updating the catalog

Update the sibling Airwindohhs checkout to its latest default branch, then run:

```sh
cmake --build build --target regenerate_catalog
```

Commit generated source, `generated/catalog.json`, and any evidence-backed entries in `config/exclusions.json` or `config/parameter_overrides.json`. See [upstream updates](docs/UPDATING.md).

## Validation

The automated suite verifies generator determinism, all 495 registrations, parameter metadata, installed bus insertion, and 27,016 offline renders across silence, impulse, noise, musical fixtures, three sample rates, four callback sizes, defaults, minima, and maxima. It rejects NaN, Inf, and extreme runaway output.

Three unsafe raw endpoints have explicit narrower inspector ranges; no effects are currently excluded. See [compatibility report](reports/compatibility-0.1.0.md).

## Development method

This project uses red/green/refactor TDD. Once a test or render baseline represents accepted behavior, a regression is fixed in production code. Changing an established test or baseline requires a human developer to approve the contract change.

## License

The wrapper is MIT licensed. Airwindohhs, Airwindows-derived code, and godot-cpp retain their own notices; see [third-party attribution](THIRD_PARTY.md).
