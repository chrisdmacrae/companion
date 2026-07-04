import { ActivityIndicator } from "react-native";
import { Center } from "./Layout";
import { Text } from "./Text";
import { colors } from "./tokens";

/** Centered loading indicator with an optional label. */
export function Spinner({ label }: { label?: string }) {
  return (
    <Center>
      <ActivityIndicator color={colors.accent} />
      {label ? (
        <Text tone="tertiary" variant="caption">
          {label}
        </Text>
      ) : null}
    </Center>
  );
}
