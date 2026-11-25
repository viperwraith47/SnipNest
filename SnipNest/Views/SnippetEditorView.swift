import SwiftUI

struct SnippetEditorView: View {
    @Bindable var snippet: Snippet
    let isCopied: Bool
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                TextField("Snippet Title", text: $snippet.title)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                    .accessibilityLabel("Snippet title")
                    .accessibilityIdentifier("snippetTitleField")

                TextField("Language", text: $snippet.language)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .accessibilityLabel("Language")
                    .accessibilityIdentifier("snippetLanguageField")
                    .accessibilityHint("For example, Swift, Shell, or JSON.")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            ZStack(alignment: .topLeading) {
                Color(nsColor: .textBackgroundColor)

                if snippet.content.isEmpty {
                    Text("Write or paste a snippet…")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 29)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $snippet.content)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .accessibilityLabel("Snippet content")
                    .accessibilityIdentifier("snippetContentEditor")
            }

            Divider()

            HStack {
                Label("Stored locally", systemImage: "internaldrive")
                    .accessibilityLabel("Stored locally on this Mac")
                Spacer()
                Text("Edited \(snippet.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(snippet.displayTitle)
        .onChange(of: snippet.title, onEdit)
        .onChange(of: snippet.language, onEdit)
        .onChange(of: snippet.content, onEdit)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCopy) {
                    Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent)
                .disabled(snippet.content.isEmpty)
                .accessibilityLabel(isCopied ? "Snippet copied" : "Copy Snippet")
                .accessibilityIdentifier("copySnippetButton")
                .accessibilityHint("Copies the snippet content to the clipboard.")
            }

            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Snippet", systemImage: "trash")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Delete Snippet")
                .accessibilityIdentifier("deleteSnippetButton")
                .accessibilityHint("Asks for confirmation before permanently deleting this snippet.")
            }
        }
    }
}
