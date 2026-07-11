# Updating upstream

Airwindohhs follows the latest default branch of the maintained `jinpavg/airwindohhs` fork, whose upstream is `isabelgk/airwindohhs`. The resolved commit in a release is provenance, not a permanent update pin.

1. Fetch and fast-forward the sibling Airwindohhs checkout.
2. Run Airwindohhs' own `scripts/check_compile.py` gate.
3. Regenerate this catalog.
4. Review `generated/catalog.json` for added, removed, renamed, or reparameterized effects.
5. Run the full standalone render suite and Godot smoke test.
6. Add an exclusion only when an effect cannot meet build, platform, bounded-processing, or finite-output requirements. Record its ID, reason, evidence, and review date.
7. Prefer a narrow `parameter_overrides.json` bound when only an invalid mathematical endpoint is unsafe.
8. Create a release manifest recording the resolved Airwindohhs commit, underlying Airwindows source, godot-cpp revision, generator version, license, and validation summary.

Do not copy Vroom's Unreal wrapper classes or its historical header workarounds. General fixes should land in the maintained Airwindohhs fork so every non-Unreal consumer benefits.
