#!/usr/bin/env bash
# Signs the macOS dylibs with a Developer ID Application identity and notarizes
# them, so a downloaded copy loads in the Godot editor without a Gatekeeper
# block and without anyone running `xattr` by hand. Run on the Mac agent after
# ci/build_macos.sh (and before ci/test_macos.sh, so the tested bytes are the
# shipped bytes).
#
# Notarization is by code hash: Apple registers the signed dylibs' hashes, and
# those exact binaries then pass Gatekeeper's online check wherever they appear,
# including inside the final multi-platform addon zip. Loose dylibs cannot be
# stapled, so first use on a fully offline Mac still needs network once; that is
# acceptable for a networked internal team.
#
# The signing identity must be a "Developer ID Application" certificate; an
# "Apple Development"/"Apple Distribution" cert signs cleanly but notarization
# rejects it as Invalid.
#
# Required environment (set as TeamCity parameters). If either is unset the
# script skips signing so local builds without the cert still succeed:
#   AIRWINDOHHS_SIGNING_IDENTITY  e.g. "Developer ID Application: Team Name (TEAMID)"
#                                 (list options: security find-identity -v -p codesigning)
#   AIRWINDOHHS_NOTARY_PROFILE    notarytool keychain profile created once with
#                                 `xcrun notarytool store-credentials`
# Optional, for daemon-run agents whose login keychain is locked:
#   AIRWINDOHHS_SIGNING_KEYCHAIN   keychain holding the Developer ID identity
#   AIRWINDOHHS_KEYCHAIN_PASSWORD  password to unlock it
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$SOURCE_DIR/demo/addons/airwindohhs_godot/bin"

if [[ -z "${AIRWINDOHHS_SIGNING_IDENTITY:-}" || -z "${AIRWINDOHHS_NOTARY_PROFILE:-}" ]]; then
    echo "AIRWINDOHHS_SIGNING_IDENTITY / AIRWINDOHHS_NOTARY_PROFILE not set; skipping macOS signing." >&2
    echo "Distributed dylibs will be unsigned and require 'xattr -dr com.apple.quarantine'." >&2
    exit 0
fi

dylibs=()
for name in libairwindohhs_godot.macos.template_debug.dylib \
            libairwindohhs_godot.macos.template_release.dylib; do
    path="$BIN_DIR/$name"
    if [[ ! -f "$path" ]]; then
        echo "Expected macOS dylib not found: $path (run ci/build_macos.sh first)." >&2
        exit 1
    fi
    dylibs+=("$path")
done

# A daemon-run agent's login keychain is locked; unlock the signing keychain if
# one was provided.
if [[ -n "${AIRWINDOHHS_SIGNING_KEYCHAIN:-}" && -n "${AIRWINDOHHS_KEYCHAIN_PASSWORD:-}" ]]; then
    security unlock-keychain -p "$AIRWINDOHHS_KEYCHAIN_PASSWORD" "$AIRWINDOHHS_SIGNING_KEYCHAIN"
fi

# --options runtime (hardened runtime) and --timestamp are both required for
# notarization to succeed.
for dylib in "${dylibs[@]}"; do
    echo "Signing $dylib"
    codesign --force --timestamp --options runtime \
        --sign "$AIRWINDOHHS_SIGNING_IDENTITY" \
        ${AIRWINDOHHS_SIGNING_KEYCHAIN:+--keychain "$AIRWINDOHHS_SIGNING_KEYCHAIN"} \
        "$dylib"
    codesign --verify --strict --verbose=2 "$dylib"
done

# Notarize a zip containing only the macOS dylibs; the non-macOS artifacts do
# not need — and iOS static archives would complicate — notarization.
staging="$(mktemp -d)"
cp "${dylibs[@]}" "$staging/"
notarization_zip="$staging/airwindohhs_godot_macos.zip"
ditto -c -k "$staging" "$notarization_zip"

echo "Submitting to Apple notary service"
# `notarytool submit --wait` exits 0 whenever processing completes, including
# an Invalid result, so the status has to be inspected explicitly. JSON output
# suppresses the streaming progress lines and yields one object to parse.
submit_output="$(xcrun notarytool submit "$notarization_zip" \
    --keychain-profile "$AIRWINDOHHS_NOTARY_PROFILE" --wait --output-format json)"
submission_id="$(printf '%s' "$submit_output" | plutil -extract id raw -o - - 2>/dev/null || true)"
status="$(printf '%s' "$submit_output" | plutil -extract status raw -o - - 2>/dev/null || true)"
echo "Notarization status: ${status:-unknown} (submission ${submission_id:-unknown})"

if [[ "$status" != "Accepted" ]]; then
    echo "Notarization failed. Per-file reasons:" >&2
    if [[ -n "$submission_id" ]]; then
        xcrun notarytool log "$submission_id" \
            --keychain-profile "$AIRWINDOHHS_NOTARY_PROFILE" >&2 || true
    fi
    exit 1
fi

echo "macOS dylibs signed and notarized by hash; ready to package."
