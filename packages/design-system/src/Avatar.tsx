import { StyleSheet, View } from "react-native";
import { Text } from "./Text";
import { colors, radius } from "./tokens";

export interface AvatarProps {
  name: string;
  size?: "sm" | "md";
}

/** Circular initials avatar. */
export function Avatar({ name, size = "md" }: AvatarProps) {
  const dim = size === "sm" ? 26 : 32;
  const initials = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? "")
    .join("");
  return (
    <View style={[styles.avatar, { width: dim, height: dim, borderRadius: radius.full }]}>
      <Text variant="caption" tone="inverse" style={styles.initials}>
        {initials}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  avatar: { alignItems: "center", justifyContent: "center", backgroundColor: colors.gray700, flexShrink: 0 },
  initials: { fontWeight: "600" },
});
