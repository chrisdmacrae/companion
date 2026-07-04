import type { StyleProp } from "react-native";

// Wails v3 window-drag hints. Applying `--wails-draggable: drag` to an element makes
// it a window drag handle on desktop; `no-drag` opts an interactive child back out.
// The property inherits, so a draggable container + no-drag controls is all it takes.
// On web these are unknown CSS custom properties and are simply ignored.

export const dragRegion: StyleProp = { "--wails-draggable": "drag" };
export const noDragRegion: StyleProp = { "--wails-draggable": "no-drag" };
