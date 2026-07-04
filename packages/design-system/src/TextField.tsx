import { StyleSheet, TextInput } from "react-native";
import { colors, font } from "./tokens";

export type FieldVariant = "title" | "prose";

export interface TextFieldProps {
  value?: string;
  onChangeText?: (text: string) => void;
  placeholder?: string;
  multiline?: boolean;
  autoFocus?: boolean;
  variant?: FieldVariant;
}

/** Borderless, document-style editable field for the note editor. "title" is a
 * large display heading; "prose" is the flowing body. Both feel like writing on the
 * page, not filling in a form (per the design system's reading aesthetic). */
export function TextField({
  value,
  onChangeText,
  placeholder,
  multiline,
  autoFocus,
  variant = "prose",
}: TextFieldProps) {
  return (
    <TextInput
      value={value}
      onChangeText={onChangeText}
      placeholder={placeholder}
      placeholderTextColor={colors.textTertiary}
      multiline={multiline}
      autoFocus={autoFocus}
      style={variant === "title" ? styles.title : styles.prose}
    />
  );
}

const styles = StyleSheet.create({
  title: {
    fontFamily: font.sans,
    fontSize: font.size["3xl"],
    fontWeight: font.weight.semibold,
    letterSpacing: font.tracking.tight,
    color: colors.textPrimary,
  },
  prose: {
    fontFamily: font.sans,
    fontSize: font.size.md,
    lineHeight: 26,
    color: colors.textPrimary,
    flex: 1,
    textAlignVertical: "top",
  },
});
