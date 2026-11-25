import AppKit
import SwiftData
import SwiftUI

enum AppSettings {
    static let showMenuBarKey = "showMenuBar"
}

struct SnippetActions {
    let create: () -> Void
    let copy: () -> Void
    let delete: () -> Void
    let canCopy: Bool
    let canDelete: Bool
}

private struct FocusedSnippetActionsKey: FocusedValueKey {
    typealias Value = SnippetActions
}

extension FocusedValues {
    var snippetActions: SnippetActions? {
        get { self[FocusedSnippetActionsKey.self] }
        set { self[FocusedSnippetActionsKey.self] = newValue }
    }
}

@main
@MainActor
struct SnipNestApp: App {
    @AppStorage(AppSettings.showMenuBarKey) private var showMenuBar = true
    @FocusedValue(\.snippetActions) private var snippetActions

    private let modelContainer: ModelContainer?
    private let persistenceError: UserError?

    init() {
        do {
            if let testStoreName = ProcessInfo.processInfo.environment["SNIPNEST_TEST_STORE"] {
                let storeURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(testStoreName, isDirectory: false)
                let configuration = ModelConfiguration(url: storeURL)
                modelContainer = try ModelContainer(for: Snippet.self, configurations: configuration)
            } else {
                modelContainer = try ModelContainer(for: Snippet.self)
            }
            persistenceError = nil
        } catch {
            modelContainer = nil
            persistenceError = UserError(
                title: "SnipNest Can’t Open Storage",
                error: error
            )
        }
    }

    var body: some Scene {
        WindowGroup("SnipNest", id: "main") {
            mainContent
                .frame(
                    minWidth: 760,
                    idealWidth: 1_000,
                    maxWidth: .infinity,
                    minHeight: 520,
                    idealHeight: 680,
                    maxHeight: .infinity
                )
        }
        .defaultSize(width: 1_000, height: 680)
        .defaultLaunchBehavior(.presented)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Snippet") {
                    snippetActions?.create()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(snippetActions == nil)
            }

            CommandGroup(after: .pasteboard) {
                Button("Copy Snippet") {
                    snippetActions?.copy()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(snippetActions?.canCopy != true)

                Divider()

                Button("Delete Snippet…") {
                    snippetActions?.delete()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(snippetActions?.canDelete != true)
            }
        }

        MenuBarExtra(
            "SnipNest",
            systemImage: "curlybraces.square",
            isInserted: $showMenuBar
        ) {
            menuBarContent
                .frame(width: 360, height: 480)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var mainContent: some View {
        if let modelContainer {
            ContentView()
                .modelContainer(modelContainer)
        } else if let persistenceError {
            PersistenceFailureView(error: persistenceError)
        }
    }

    @ViewBuilder
    private var menuBarContent: some View {
        if let modelContainer {
            MenuBarView()
                .modelContainer(modelContainer)
        } else if let persistenceError {
            PersistenceFailureView(error: persistenceError)
        }
    }
}

private struct PersistenceFailureView: View {
    let error: UserError

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(error.message)
                .multilineTextAlignment(.center)
        } actions: {
            Button("Quit SnipNest") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(24)
    }
}
