#!/usr/bin/env bash
#
# Cross-compile core/cmd/mobile to a visionOS xcframework (device + simulator).
#
# Go has no GOOS=visionos and gomobile's Apple targets stop at ios/iossimulator/
# macos/maccatalyst, so there is no supported one-shot build. This script hand-rolls
# it, but leans on gomobile for the fiddly parts instead of reinventing them:
#
#   1. Run `gomobile bind -target=ios -work` once. We do NOT ship its iOS output —
#      we harvest two things from its preserved work dir: the generated gobind glue
#      package (+ its go.mod/GOPATH) and the Core.framework *skeleton* (Headers +
#      module.modulemap + Info.plist, all of which are platform-independent).
#   2. Rebuild only the static archive for each visionOS slice by re-running the exact
#      `go build -buildmode=c-archive` gomobile would run, but with the visionOS SDK
#      and an `arm64-apple-xros1.0[-simulator]` target passed through CGO_*FLAGS
#      (this is how gomobile itself points clang at an SDK — no clang wrapper needed).
#   3. Drop the archive into a copy of the skeleton and `xcodebuild -create-xcframework`.
#
# Why no vtool surgery (contrary to the usual community recipe): with Go 1.26, passing
# `-target arm64-apple-xros1.0` through CGO_LDFLAGS makes the Go linker stamp every
# object's LC_BUILD_VERSION as VISIONOS / VISIONOSSIMULATOR already. `xcodebuild
# -create-xcframework` verifies those stamps, so a correct build is self-checking. If a
# future toolchain regresses to iOS stamping, patch members with
# `vtool -set-build-version xros <min> <sdk> -replace` before create-xcframework.
#
# Usage: tools/visionos/build-xcframework.sh [output-xcframework-path]
#   Defaults to build/Core.xcframework. Run from the repo root (the Makefile does).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GO="${GO:-go}"
XROS_MIN="${XROS_MIN:-1.0}"
BIND_PKG="./cmd/mobile"
OUT_XC="${1:-$REPO_ROOT/build/Core.xcframework}"

command -v gomobile >/dev/null 2>&1 || {
  echo "error: gomobile not found; run 'make gomobile-init'" >&2; exit 1
}

DEV_SDK="$(xcrun --sdk xros --show-sdk-path)"
SIM_SDK="$(xcrun --sdk xrsimulator --show-sdk-path)"
CLANG="$(xcrun --sdk xros --find clang)"

WORK="$(mktemp -d)"
STAGE="$(mktemp -d)"
cleanup() { [ -n "${KEEP_WORK:-}" ] || rm -rf "$WORK" "$STAGE"; }
trap cleanup EXIT

echo ">> generating gomobile glue + framework skeleton (via a throwaway iOS bind)"
# -work preserves the generated glue tree and prints `WORK=<dir>`; we harvest two
# things from that iOS bind: (a) the generated `./gobind` package + GOPATH, to rebuild
# archives against; (b) the Core.framework skeleton (Headers + module.modulemap +
# Info.plist, all platform-independent) from the produced xcframework. We name the
# throwaway output Core.xcframework so the framework/module is named `Core` (gomobile
# derives the name from the -o basename) — that's what the app's `import Core` expects.
GOMOBILE_LOG="$WORK/gomobile.log"
IOS_XC="$WORK/Core.xcframework"
( cd "$REPO_ROOT/core" && gomobile bind -target=ios -work \
    -o "$IOS_XC" "$BIND_PKG" ) >"$GOMOBILE_LOG" 2>&1
GEN_WORK="$(sed -n 's/^WORK=//p' "$GOMOBILE_LOG" | grep -v go-build | head -1)"
[ -n "$GEN_WORK" ] || { echo "error: could not find gomobile WORK dir" >&2; cat "$GOMOBILE_LOG" >&2; exit 1; }

SRC_TREE="$GEN_WORK/ios/src-arm64"           # the ./gobind package gomobile compiles
GLUE_GOPATH="$GEN_WORK/ios"                  # GOPATH gomobile builds it under
SKEL="$IOS_XC/ios-arm64/Core.framework"      # Headers + Modules + Info.plist (arch-independent)
[ -d "$SRC_TREE/gobind" ] || { echo "error: generated glue package missing at $SRC_TREE/gobind" >&2; cat "$GOMOBILE_LOG" >&2; exit 1; }
[ -d "$SKEL/Headers" ]     || { echo "error: framework skeleton missing at $SKEL" >&2; cat "$GOMOBILE_LOG" >&2; exit 1; }

# build_slice <slice-id> <sdk-path> <target-triple> -> emits $STAGE/<slice-id>/Core.framework
build_slice() {
  local slice="$1" sdk="$2" triple="$3"
  local archive="$STAGE/$slice.a"
  local fw="$STAGE/$slice/Core.framework"
  echo ">> building $slice ($triple)"
  local flags="-isysroot $sdk -target $triple -arch arm64"
  ( cd "$SRC_TREE" && \
    GOOS=ios GOARCH=arm64 GOFLAGS=-tags=ios CGO_ENABLED=1 \
    CC="$CLANG" CXX="${CLANG}++" \
    CGO_CFLAGS="$flags" CGO_CXXFLAGS="$flags" CGO_LDFLAGS="$flags" \
    GOPATH="$GLUE_GOPATH:$($GO env GOPATH)" \
    "$GO" build -buildmode=c-archive -o "$archive" ./gobind )
  mkdir -p "$fw/Headers" "$fw/Modules"
  cp "$SKEL"/Headers/* "$fw/Headers/"
  cp "$SKEL"/Modules/module.modulemap "$fw/Modules/"
  cp "$SKEL"/Info.plist "$fw/Info.plist"
  # Match gomobile: the framework binary is a universal (fat) wrapper around the archive.
  xcrun lipo -create "$archive" -output "$fw/Core"
}

build_slice "xros-arm64"           "$DEV_SDK" "arm64-apple-xros${XROS_MIN}"
build_slice "xros-arm64-simulator" "$SIM_SDK" "arm64-apple-xros${XROS_MIN}-simulator"

echo ">> assembling xcframework -> $OUT_XC"
rm -rf "$OUT_XC"
mkdir -p "$(dirname "$OUT_XC")"
xcodebuild -create-xcframework \
  -framework "$STAGE/xros-arm64/Core.framework" \
  -framework "$STAGE/xros-arm64-simulator/Core.framework" \
  -output "$OUT_XC"

echo ">> done: $OUT_XC"
