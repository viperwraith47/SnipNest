import Foundation
import Testing
@testable import SnipNest

struct SnippetFilterTests {
    @Test
    func blankQueryReturnsAllSnippetsNewestFirst() {
        let older = makeSnippet(title: "Older", day: 1)
        let newer = makeSnippet(title: "Newer", day: 2)
        let middle = makeSnippet(title: "Middle", day: 1.5)

        let result = SnippetFilter.filter([older, newer, middle], query: " \n\t ")

        #expect(result.map(\.id) == [newer.id, middle.id, older.id])
    }

    @Test
    func searchMatchesTitleContentAndLanguageWithoutCaseSensitivity() {
        let titleMatch = makeSnippet(title: "Deployment Helper", content: "printf hello", language: "Shell", day: 1)
        let contentMatch = makeSnippet(title: "Greeting", content: "print(\"DEPLOYMENT\")", language: "Swift", day: 2)
        let languageMatch = makeSnippet(title: "Example", content: "value", language: "DeploymentScript", day: 3)
        let other = makeSnippet(title: "Unrelated", content: "Nothing here", language: "JSON", day: 4)

        let result = SnippetFilter.filter([titleMatch, contentMatch, languageMatch, other], query: "deployment")

        #expect(result.map(\.id) == [languageMatch.id, contentMatch.id, titleMatch.id])
    }

    @Test
    func searchTrimsSurroundingWhitespace() {
        let snippet = makeSnippet(title: "Swift Formatting", day: 1)

        let result = SnippetFilter.filter([snippet], query: "  formatting  ")

        #expect(result == [snippet])
    }

    @Test
    func searchReturnsEmptyArrayWhenNothingMatches() {
        let snippet = makeSnippet(title: "Swift Formatting", content: "swift format", day: 1)

        let result = SnippetFilter.filter([snippet], query: "ruby")

        #expect(result.isEmpty)
    }

    @Test
    func equalModificationDatesHaveStableOrdering() {
        let idA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let idB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let first = makeSnippet(id: idA, title: "A", day: 1)
        let second = makeSnippet(id: idB, title: "B", day: 1)

        let result = SnippetFilter.filter([second, first], query: "")

        #expect(result.map(\.id) == [idA, idB])
    }

    @Test
    func displayFieldsFallBackForBlankInput() {
        let snippet = Snippet(title: " \n ", language: "\t")

        #expect(snippet.displayTitle == "Untitled Snippet")
        #expect(snippet.displayLanguage == "Plain Text")
    }

    @Test
    func displayFieldsTrimSurroundingWhitespace() {
        let snippet = Snippet(title: "  Build Script  ", language: "  Shell  ")

        #expect(snippet.displayTitle == "Build Script")
        #expect(snippet.displayLanguage == "Shell")
    }

    private func makeSnippet(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        language: String = "",
        day: TimeInterval
    ) -> Snippet {
        Snippet(
            id: id,
            title: title,
            content: content,
            language: language,
            createdAt: Date(timeIntervalSince1970: day * 86_400),
            modifiedAt: Date(timeIntervalSince1970: day * 86_400)
        )
    }
}
