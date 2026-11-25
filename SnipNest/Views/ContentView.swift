import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Snippet.modifiedAt, order: .reverse)]) private var snippets: [Snippet]

    @State private var selection: UUID?
    @State private var searchText = ""
    @State private var copiedSnippetID: UUID?
    @State private var snippetPendingDeletion: Snippet?
    @State private var isDeleteConfirmationPresented = false
    @State private var presentedError: UserError?

    private var store: SnippetStore {
        SnippetStore(modelContext: modelContext)
    }

    private var filteredSnippets: [Snippet] {
        SnippetFilter.filter(snippets, query: searchText)
    }

    private var selectedSnippet: Snippet? {
        snippets.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if snippets.isEmpty {
                    ContentUnavailableView {
                        Label("No Snippets Yet", systemImage: "curlybraces.square")
                    } description: {
                        Text("Save a useful command, template, or code fragment for quick copying.")
                    } actions: {
                        Button("Create Your First Snippet", action: createSnippet)
                            .buttonStyle(.glassProminent)
                    }
                    .listRowSeparator(.hidden)
                } else if filteredSnippets.isEmpty {
                    ContentUnavailableView(
                        "No Matching Snippets",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different title, language, or snippet search.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredSnippets) { snippet in
                        snippetRow(snippet)
                            .tag(snippet.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("SnipNest")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search Snippets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createSnippet) {
                        Label("New Snippet", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel("New Snippet")
                    .accessibilityIdentifier("newSnippetButton")
                    .accessibilityHint("Creates a snippet and opens its editor.")
                }
            }
        } detail: {
            if let selectedSnippet {
                SnippetEditorView(
                    snippet: selectedSnippet,
                    isCopied: copiedSnippetID == selectedSnippet.id,
                    onEdit: {
                        do {
                            try store.saveChanges(to: selectedSnippet)
                        } catch {
                            present(error)
                        }
                    },
                    onCopy: {
                        copy(selectedSnippet)
                    },
                    onDelete: {
                        requestDelete(selectedSnippet)
                    }
                )
                .id(selectedSnippet.id)
            } else {
                ContentUnavailableView {
                    Label("Select a Snippet", systemImage: "text.cursor")
                } description: {
                    Text("Choose a snippet from the sidebar, or create a new one.")
                } actions: {
                    Button("New Snippet", action: createSnippet)
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .focusedValue(
            \.snippetActions,
            SnippetActions(
                create: createSnippet,
                copy: {
                    if let selectedSnippet {
                        copy(selectedSnippet)
                    }
                },
                delete: {
                    if let selectedSnippet {
                        requestDelete(selectedSnippet)
                    }
                },
                canCopy: selectedSnippet?.content.isEmpty == false,
                canDelete: selectedSnippet != nil
            )
        )
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Delete This Snippet?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Snippet", role: .destructive) {
                deletePendingSnippet()
            }
            Button("Cancel", role: .cancel) {
                snippetPendingDeletion = nil
            }
        } message: {
            Text("This permanently removes the snippet from this Mac.")
        }
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(snippet.displayTitle)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(snippet.displayLanguage)
                Text("•")
                Text(snippet.modifiedAt, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
        .draggable(snippet.content)
        .contextMenu {
            Button {
                copy(snippet)
            } label: {
                Label("Copy Snippet", systemImage: "doc.on.doc")
            }
            .disabled(snippet.content.isEmpty)

            Button(role: .destructive) {
                requestDelete(snippet)
            } label: {
                Label("Delete Snippet", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snippet.displayTitle), \(snippet.displayLanguage)")
        .accessibilityHint("Select to edit. Use the rotor for copy and delete actions.")
        .accessibilityAction(named: "Copy Snippet") {
            copy(snippet)
        }
        .accessibilityAction(named: "Delete Snippet") {
            requestDelete(snippet)
        }
    }

    private func createSnippet() {
        do {
            let snippet = try store.createSnippet()
            selection = snippet.id
            searchText = ""
        } catch {
            present(error)
        }
    }

    private func copy(_ snippet: Snippet) {
        guard !snippet.content.isEmpty else { return }

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
            present(error)
        }
    }

    private func requestDelete(_ snippet: Snippet) {
        snippetPendingDeletion = snippet
        isDeleteConfirmationPresented = true
    }

    private func deletePendingSnippet() {
        guard let snippet = snippetPendingDeletion else { return }

        do {
            try store.delete(snippet)
            if selection == snippet.id {
                selection = nil
            }
            snippetPendingDeletion = nil
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        presentedError = UserError(error: error)
    }
}
