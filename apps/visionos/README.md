# Companion — visionOS

A native SwiftUI/RealityKit visionOS app that consumes the shared Go core directly via a
cross-compiled `Core.xcframework` (not through the Expo module the RN mobile app uses).

This milestone is a **smoke test**: it boots the core and proves an `invoke` round-trips
in the visionOS Simulator (reads `core.version` + `tasks.list`). The full spatial UI is a
follow-on — only the Go core is shared with desktop/mobile/web.

## Architecture

- **`Sources/CompanionCore.swift`** — Swift wrapper around the gomobile-bound Go core
  (`MobileNew` / `invoke` / event stream). The visionOS analogue of
  `apps/mobile/modules/companion-core/ios/CompanionCoreModule.swift`, minus Expo.
- **`Sources/CompanionApp.swift`** — SwiftUI `@main` app + smoke-test view.
- **`vendor/Core.xcframework`** — the cross-compiled core (gitignored; regenerated).
- **`project.yml`** — XcodeGen project definition (source of truth). The `.xcodeproj` is
  generated and gitignored.

## How the core is cross-compiled

Go has no `GOOS=visionos` and gomobile has no visionOS target, so the xcframework is
hand-rolled by [`tools/visionos/build-xcframework.sh`](../../tools/visionos/build-xcframework.sh):
it reuses gomobile's generated ObjC glue + framework skeleton (from a throwaway iOS bind),
then rebuilds the static archive for the `arm64-apple-xros1.0` (device) and
`arm64-apple-xros1.0-simulator` targets and packages both into an xcframework. With Go
1.26, passing the `-target` triple through `CGO_LDFLAGS` stamps every object's Mach-O
`LC_BUILD_VERSION` as visionOS, so no `vtool` patching is needed. See that script's header
for the full rationale.

## Build & run

```sh
brew install xcodegen        # one-time (project generator)

make visionos-artifacts      # cross-compile the core -> vendor/Core.xcframework
make visionos-project        # generate Companion.xcodeproj from project.yml
open apps/visionos/Companion.xcodeproj   # or:
make visionos-run            # build + install + launch in the visionOS Simulator
```
