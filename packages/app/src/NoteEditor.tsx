import { useState } from "react";
import { ScrollView, View } from "react-native";
import type { Note } from "@companion/core-bridge";
import { Badge, Icon, IconButton, Text, TextField, colors, layout, space } from "@companion/design-system";

export interface NoteEditorProps {
  note: Note;
  onChange: (id: string, fields: { title?: string; contentMd?: string }) => void;
  /** Shown as a pop-out (focus) action in the note's sub-toolbar when provided. */
  onPopOut?: (id: string) => void;
  /** Shown as a delete action in the note's sub-toolbar when provided. */
  onDelete?: (id: string) => void;
}

/** The document-style editor for a single note, with a sub-toolbar of note-scoped
 * actions (sync status, pop-out, delete). App-level chrome stays in the app toolbar. */
export function NoteEditor({ note, onChange, onPopOut, onDelete }: NoteEditorProps) {
  const [title, setTitle] = useState(note.title);
  const [content, setContent] = useState(note.contentMd);

  return (
    <View style={{ flex: 1 }}>
      {/* note sub-toolbar */}
      <View style={styles.subToolbar}>
        <Badge tone="accent" label={note.version === 0 ? "unsynced" : "v" + note.version} />
        <View style={{ flex: 1 }} />
        {onPopOut ? (
          <IconButton label="Open in new window" size="sm" onPress={() => onPopOut(note.id)}>
            <Icon name="external" size={15} color={colors.textTertiary} />
          </IconButton>
        ) : null}
        {onDelete ? (
          <IconButton label="Delete note" size="sm" onPress={() => onDelete(note.id)}>
            <Icon name="trash" size={16} color={colors.textTertiary} />
          </IconButton>
        ) : null}
      </View>

      <ScrollView style={{ flex: 1 }} contentContainerStyle={styles.doc}>
        <TextField
          variant="title"
          value={title}
          placeholder="Untitled"
          onChangeText={(t) => {
            setTitle(t);
            onChange(note.id, { title: t });
          }}
        />
        <Text variant="mono" tone="tertiary" style={{ marginTop: space.md, marginBottom: space.xl }}>
          Edited {new Date(note.updatedAt).toLocaleString()}
        </Text>
        <TextField
          variant="prose"
          value={content}
          placeholder="Start writing — type [[ to link another note."
          multiline
          onChangeText={(t) => {
            setContent(t);
            onChange(note.id, { contentMd: t });
          }}
        />
      </ScrollView>
    </View>
  );
}

const styles = {
  subToolbar: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    gap: space.xs,
    height: 44,
    paddingHorizontal: space.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.borderSubtle,
    flexShrink: 0,
  },
  doc: {
    maxWidth: layout.contentMax,
    width: "100%" as const,
    marginHorizontal: "auto" as const,
    padding: 44,
    paddingTop: 32,
  },
};
