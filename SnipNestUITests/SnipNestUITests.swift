import AppKit
import XCTest

final class SnipNestUITests: XCTestCase {
    private var storeName: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeName = "SnipNest-UI-Tests-\(UUID().uuidString).store"
    }

    override func tearDownWithError() throws {
        storeName = nil
    }

    @MainActor
    func testCreateEditCopyPersistAndDeleteSnippet() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SNIPNEST_TEST_STORE"] = storeName
        app.launchArguments = ["-NSQuitAlwaysKeepsWindows", "NO"]
        app.launch()
        defer { app.terminate() }
        app.activate()

        openLibrary(using: app)

        let newButton = app.buttons["New Snippet"].firstMatch
        if newButton.waitForExistence(timeout: 5) {
            newButton.click()
        } else {
            let firstSnippetButton = app.buttons["Create Your First Snippet"].firstMatch
            XCTAssertTrue(firstSnippetButton.waitForExistence(timeout: 5))
            firstSnippetButton.click()
        }

        let titleField = app.textFields["snippetTitleField"].firstMatch
        let languageField = app.textFields["snippetLanguageField"].firstMatch
        let contentEditor = app.textViews["snippetContentEditor"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        XCTAssertTrue(languageField.exists)
        XCTAssertTrue(contentEditor.exists)

        titleField.click()
        titleField.typeText("Build Command")
        languageField.click()
        languageField.typeText("Shell")
        contentEditor.click()
        contentEditor.typeText("swift build")

        let copyButton = app.buttons["copySnippetButton"].firstMatch
        XCTAssertTrue(copyButton.exists)
        copyButton.click()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "swift build")

        app.terminate()
        app.launch()
        app.activate()
        openLibrary(using: app)

        let persistedRow = app.staticTexts
            .matching(NSPredicate(format: "value BEGINSWITH 'Build Command'"))
            .firstMatch
        XCTAssertTrue(persistedRow.waitForExistence(timeout: 10))
        persistedRow.click()

        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        XCTAssertEqual(titleField.value as? String, "Build Command")
        XCTAssertEqual(languageField.value as? String, "Shell")
        XCTAssertEqual(contentEditor.value as? String, "swift build")

        titleField.click()
        titleField.typeKey("a", modifierFlags: .command)
        titleField.typeText("Release Command")
        XCTAssertEqual(titleField.value as? String, "Release Command")

        let deleteButton = app.buttons["deleteSnippetButton"].firstMatch
        XCTAssertTrue(deleteButton.exists)
        deleteButton.click()

        let confirmationButton = app.sheets.buttons["Delete Snippet"].firstMatch
        XCTAssertTrue(confirmationButton.waitForExistence(timeout: 5))
        confirmationButton.click()

        XCTAssertTrue(app.staticTexts["Select a Snippet"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts
                .matching(NSPredicate(format: "value BEGINSWITH 'Release Command'"))
                .firstMatch
                .exists
        )
    }

    @MainActor
    private func openLibrary(using app: XCUIApplication) {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10))
        statusItem.click()

        let openButton = app.buttons["Open SnipNest"].firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        openButton.click()
    }
}
