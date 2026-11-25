import Foundation
import SwiftData

enum SnippetStoreError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        "SnipNest couldn’t save your changes."
    }

    var failureReason: String? {
        switch self {
        case .saveFailed(let reason):
            reason
        }
    }

    var recoverySuggestion: String? {
        "Your latest change may not be preserved. Try editing again or restart SnipNest."
    }
}

@MainActor
final class SnippetStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func createSnippet(
        title: String = "",
        content: String = "",
        language: String = ""
    ) throws -> Snippet {
        let snippet = Snippet(title: title, content: content, language: language)
        modelContext.insert(snippet)
        try save()
        return snippet
    }

    func saveChanges(to snippet: Snippet) throws {
        snippet.modifiedAt = .now
        try save()
    }

    func delete(_ snippet: Snippet) throws {
        modelContext.delete(snippet)
        try save()
    }

    func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw SnippetStoreError.saveFailed(error.localizedDescription)
        }
    }
}
