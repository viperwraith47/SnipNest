import AppKit
import SwiftData
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Query(sort: [SortDescriptor(\Snippet.modifiedAt, order: .reverse)]) private var snippets: [Snippet]

    @State private var searchText = ""
    @State private var copiedSnippetID: UUID?
    @State private var presentedError: UserError?

    private var filteredSnippets: [Snippet] {
        SnippetFilter.filter(snippets, query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search Snippets", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search snippets")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .padding(12)

            Divider()

            if snippets.isEmpty {
                ContentUnavailableView {
                    Label("No Snippets Yet", systemImage: "curlybraces.square")
                } description: {
                    Text("Create a snippet in the main window.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredSnippets.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(filteredSnippets) { snippet in
                            snippetButton(snippet)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }

            Divider()

            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 10) {
                    Button(action: openMainWindow) {
                        Label("Open SnipNest", systemImage: "macwindow")
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityHint("Opens the full snippet library.")

                    Spacer()

                    Button(action: openAppSettings) {
                        Label("Settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("SnipNest Settings")
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func snippetButton(_ snippet: Snippet) -> some View {
        Button {
            copy(snippet)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snippet.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(snippet.displayLanguage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if copiedSnippetID == snippet.id {
                    Label("Copied", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                copiedSnippetID == snippet.id ? Color.accentColor.opacity(0.12) : Color.clear,
                in: .rect(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(snippet.content.isEmpty)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copiedSnippetID == snippet.id ? "\(snippet.displayTitle) copied" : "Copy \(snippet.displayTitle)")
        .accessibilityValue(snippet.displayLanguage)
        .accessibilityHint(snippet.content.isEmpty ? "This snippet has no content to copy." : "Copies this snippet to the clipboard.")
    }

    private func copy(_ snippet: Snippet) {
        do {
            try PasteboardService.copy(snippet.content)
            copiedSnippetID = snippet.id
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if copiedSnippetID == snippet.id {
                    copiedSnippetID = nil
                }
            }
        } catch {
            presentedError = UserError(error: error)
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }

    private func openAppSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}
