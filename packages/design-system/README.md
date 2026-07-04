# @companion/design-system

The shared visual language and presentational components for every Companion client
(web + desktop today; mobile in milestone 3). Built on React Native primitives, so
the same components render via react-native-web on web/desktop and native RN on
mobile.

The look is ported from the **Companion design system**: a near-grayscale warm-neutral
surface with a single orange accent (`#f76808`), Geist / Geist Mono typography,
generous rounding, and low diffuse shadows. Quiet surface, loud content.

## What belongs here

- **Design tokens** (`tokens.ts`) — `colors`, `space`, `radius`, `font`, `shadow`,
  `control` (heights), `layout` (rail/list/content-max). The single source of truth.
- **Presentational components**
  - primitives: `Text`, `Icon` (Lucide-style), `Button`, `IconButton`, `Input`,
    `TextField` (document-style editor field), `Badge`, `Avatar`, `Spinner`
  - list/shell: `ListRow`, `RailItem`, `Frame` / `Toolbar` / `FrameTitle`
  - layout: `Row`, `Stack`, `Center`, `Divider`

Hover and press states use react-native-web's `Pressable` state (`hovered`/`pressed`);
they no-op on native, which has no hover.

## What does NOT belong here

No data fetching, no `@companion/core-bridge` dependency, nothing app-specific.
Components take plain props and render. Screens, the app shell, and business logic
live in `@companion/app`, which composes these with data from the core.

```
@companion/design-system   (how it looks)   ← this package
        ▲
@companion/app             (what it does)   ← shell + screens + CoreBridge data flow
        ▲
apps/web · apps/desktop/frontend             ← platform shells
```

The react-native ambient type shim (`src/react-native.d.ts`) lives here as the
canonical UI-layer declaration; the app and shells reference it from their tsconfig.

> Icons render as inline SVG (valid under react-native-web). A native
> `react-native-svg` variant will arrive with the mobile milestone.
