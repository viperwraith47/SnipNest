import Foundation
import SwiftData

@Model
final class Snippet {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var language: String
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        language: String = "",
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.language = language
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

extension Snippet {
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Snippet" : trimmedTitle
    }

    var displayLanguage: String {
        let trimmedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLanguage.isEmpty ? "Plain Text" : trimmedLanguage
    }
}

enum SnippetFilter {
    static func filter(_ snippets: [Snippet], query: String) -> [Snippet] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmedQuery.isEmpty
            ? snippets
            : snippets.filter { snippet in
                snippet.title.localizedCaseInsensitiveContains(trimmedQuery)
                    || snippet.content.localizedCaseInsensitiveContains(trimmedQuery)
                    || snippet.language.localizedCaseInsensitiveContains(trimmedQuery)
            }

        return matches.sorted { left, right in
            if left.modifiedAt != right.modifiedAt {
                return left.modifiedAt > right.modifiedAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }
}
