import type { ReactNode } from "react";
import { Pressable } from "react-native";
import { noDragRegion } from "./platform";
import { colors, radius } from "./tokens";

export type IconButtonSize = "sm" | "md";

export interface IconButtonProps {
  children: ReactNode;
  label: string;
  onPress?: () => void;
  size?: IconButtonSize;
  active?: boolean;
  disabled?: boolean;
}

/** Square, quiet button for a single icon (toolbars, list affordances). */
export function IconButton({ children, label, onPress, size = "md", active = false, disabled = false }: IconButtonProps) {
  const dim = size === "sm" ? 28 : 32;
  return (
    <Pressable
      onPress={disabled ? undefined : onPress}
      disabled={disabled}
      aria-label={label}
      style={({ hovered, pressed }) => [
        noDragRegion,
        {
          width: dim,
          height: dim,
          alignItems: "center",
          justifyContent: "center",
          borderRadius: radius.md,
          opacity: disabled ? 0.35 : 1,
          backgroundColor:
            disabled || (!active && !hovered && !pressed)
              ? "transparent"
              : active
                ? colors.accentSoft
                : pressed
                  ? colors.surfaceActive
                  : colors.surfaceHover,
          transform: pressed && !disabled ? [{ scale: 0.94 }] : undefined,
        },
      ]}
    >
      {children}
    </Pressable>
  );
}
