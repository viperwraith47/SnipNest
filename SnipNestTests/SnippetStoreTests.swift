import Foundation
import SwiftData
import Testing
@testable import SnipNest

@MainActor
struct SnippetStoreTests {
    @Test
    func createPersistsSnippetWithStableIdentity() throws {
        let (store, context) = try makeStore()

        let snippet = try store.createSnippet(
            title: "Greeting",
            content: "print(\"Hello\")",
            language: "Swift"
        )

        let fetched = try context.fetch(FetchDescriptor<Snippet>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == snippet.id)
        #expect(fetched.first?.title == "Greeting")
        #expect(fetched.first?.content == "print(\"Hello\")")
        #expect(fetched.first?.language == "Swift")
    }

    @Test
    func savingEditsPreservesContentAndAdvancesModificationDate() throws {
        let (store, context) = try makeStore()
        let snippet = try store.createSnippet(title: "Before", content: "old")
        let originalCreationDate = snippet.createdAt
        let originalModificationDate = snippet.modifiedAt

        snippet.title = "After"
        snippet.content = "new"
        snippet.language = "Shell"
        try store.saveChanges(to: snippet)

        let fetched = try #require(try context.fetch(FetchDescriptor<Snippet>()).first)
        #expect(fetched.title == "After")
        #expect(fetched.content == "new")
        #expect(fetched.language == "Shell")
        #expect(fetched.createdAt == originalCreationDate)
        #expect(fetched.modifiedAt > originalModificationDate)
    }

    @Test
    func deleteRemovesOnlyTheSelectedSnippet() throws {
        let (store, context) = try makeStore()
        let first = try store.createSnippet(title: "First")
        let second = try store.createSnippet(title: "Second")

        try store.delete(first)

        let fetched = try context.fetch(FetchDescriptor<Snippet>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == second.id)
    }

    @Test
    func saveErrorHasUserFacingMessageAndRecovery() {
        let error = SnippetStoreError.saveFailed("The disk is full.")

        let presentedError = UserError(error: error)

        #expect(presentedError.message.contains("SnipNest couldn’t save your changes."))
        #expect(presentedError.message.contains("The disk is full."))
        #expect(presentedError.message.contains("restart SnipNest"))
    }

    private func makeStore() throws -> (SnippetStore, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Snippet.self, configurations: configuration)
        let context = ModelContext(container)
        return (SnippetStore(modelContext: context), context)
    }
}
