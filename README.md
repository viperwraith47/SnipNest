# SnipNest

SnipNest is a fully native, offline snippet library for macOS. Keep reusable commands, templates, and code fragments in a searchable main window, then copy them from the menu bar without opening another app.

## Features

- Create, edit, search, and delete plain-text snippets with an optional language label.
- Copy from the main window or the searchable menu-bar palette.
- Drag a snippet from the sidebar into another app as plain text.
- Automatic local saves with SwiftData and modification-time sorting.
- Native menus and shortcuts: New Snippet (`Cmd-N`), Copy Snippet (`Shift-Cmd-C`), Delete Snippet (`Cmd-Delete`), and Settings (`Cmd-,`).
- Optional menu-bar icon and Launch at Login.
- Liquid Glass on Tahoe's navigation and control layer, standard sidebar and toolbar behavior, light/dark appearance, and system accessibility adaptations.
- VoiceOver labels and hints, keyboard navigation, empty states, delete confirmation, and user-facing storage, clipboard, and login-item errors.

SnipNest deliberately does not auto-paste, request Accessibility access, provide syntax highlighting, sync over a network, or include analytics.

## Requirements

- macOS 26 Tahoe or later
- Xcode 26 or later with a macOS 26 SDK
- An Apple development team for signed builds, or Sign to Run Locally for personal use

There are no package dependencies, backend services, API keys, or paid services.

## Build and run

1. Open `SnipNest.xcodeproj` in Xcode 26 or later.
2. Select the **SnipNest** scheme and **My Mac**.
3. Open the SnipNest target's **Signing & Capabilities** tab. Select your team under Signing, or choose **Sign to Run Locally**. Change the example bundle identifier if Xcode asks for a unique one.
4. Set the deployment target to **macOS 26.0** or later. It is already configured as 26.0.
5. Press `Cmd-R`.

The app opens its main window and adds a curly-braces icon to the menu bar. Create a snippet with `Cmd-N`; edits save automatically. Use the menu-bar search and click a snippet to copy it.

### Command-line build

```sh
xcodebuild build \
  -project SnipNest.xcodeproj \
  -scheme SnipNest \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Run the tests

In Xcode, select **SnipNest** and press `Cmd-U` for the unit tests. Select **SnipNestUITests** and press `Cmd-U` for the end-to-end UI test. Separate schemes prevent the unit-test host and UI-test app from competing for the same accessibility session.

From the directory containing this README, run the unit tests:

```sh
xcodebuild test \
  -project SnipNest.xcodeproj \
  -scheme SnipNest \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Then run the UI test:

```sh
xcodebuild test \
  -project SnipNest.xcodeproj \
  -scheme SnipNestUITests \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES
```

The ad-hoc identity signs only on the local machine and lets the XCUITest runner bootstrap without a paid developer account. Use your normal development signing settings when running through Xcode.

The Swift Testing suite covers search across title/content/language, whitespace and case handling, deterministic ordering, display fallbacks, in-memory SwiftData create/edit/delete persistence, and actionable save-error presentation. A native XCUITest also exercises create, edit, clipboard copy, relaunch persistence, and confirmed deletion through the running app. The UI test uses its own temporary SwiftData file and never touches the normal snippet library.

## Creating a fresh Xcode project instead

The included project is ready to use. To drop the sources into a new project:

1. In Xcode, choose **File > New > Project > macOS > App**. Use SwiftUI for Interface, SwiftData for Storage if offered, and Swift for Language. Set the product name to **SnipNest** and include tests.
2. Set the app and test targets to macOS 26.0 and Swift 6. Remove the template's `ContentView.swift` and model file.
3. Add every Swift file under `SnipNest/` to the app target, preserving the Models, Services, and Views groups. Add `SnipNest/Assets.xcassets` to app resources.
4. Add both files under `SnipNestTests/` to the unit-test target. If your app module has a different product name, update `@testable import SnipNest` accordingly. For the end-to-end test, add a macOS UI Testing Bundle target named `SnipNestUITests`, add `SnipNestUITests/SnipNestUITests.swift`, and set its target application to SnipNest.
5. Set **Asset Catalog Compiler App Icon Name** to `AppIcon` and **Global Accent Color Name** to `AccentColor`, or use the provided asset catalog through the target's General settings.
6. Enable **App Sandbox** in Signing & Capabilities. Keep the default minimum sandbox access: no network client/server, user-selected file access, or other capabilities are needed. The included `SnipNest/SnipNest.entitlements` contains the equivalent single sandbox key.
7. Enable **Hardened Runtime** for Release/notarized builds. Use automatic signing for local development.
8. No custom Info.plist keys are required beyond the generated display name and application category. Do not set `LSUIElement`; SnipNest remains a regular Dock app.
9. Set the generated display name to **SnipNest**, then build and test as above.

## Architecture

- `SnipNest/SnipNestApp.swift` — App entry, shared `ModelContainer`, main/menu-bar/settings scenes, and global menu commands.
- `SnipNest/Models/Snippet.swift` — SwiftData entity, display normalization, and pure deterministic search/filter logic.
- `SnipNest/Services/SnippetStore.swift` — Main-actor CRUD and explicit save-error translation around `ModelContext`.
- `SnipNest/Services/PasteboardService.swift` — Checked `NSPasteboard` writes.
- `SnipNest/Services/LoginItemService.swift` — `SMAppService` registration, unregistration, and approval state.
- `SnipNest/Services/UserError.swift` — Alert-ready error messages with recovery suggestions.
- `SnipNest/Views/ContentView.swift` — Searchable split view, selection, commands, and CRUD coordination.
- `SnipNest/Views/SnippetEditorView.swift` — Autosaving title/language/content editor.
- `SnipNest/Views/MenuBarView.swift` — Liquid Glass quick-search controls and plain-content result list.
- `SnipNest/Views/SettingsView.swift` — Native grouped settings form.
- `SnipNestTests/` — Unit tests using an in-memory SwiftData container.
- `SnipNestUITests/` — End-to-end UI coverage using an isolated temporary store supplied through `SNIPNEST_TEST_STORE`.

The app and all scenes share one SwiftData container. Search remains a pure function so it can be tested independently of views. AppKit is used only for pasteboard access, app activation, and termination; ServiceManagement is used only for Launch at Login.

## Privacy and data

Snippets are stored in the app's local SwiftData container. SnipNest has no network entitlement and sends nothing to a server. Copying replaces the current general pasteboard contents, as expected for a clipboard action. Login-item changes may require approval in **System Settings > General > Login Items & Extensions**.
