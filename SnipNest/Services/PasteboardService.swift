import AppKit

enum PasteboardError: LocalizedError {
    case copyFailed

    var errorDescription: String? {
        "SnipNest couldn’t copy this snippet."
    }

    var recoverySuggestion: String? {
        "Try copying again. If the problem continues, restart SnipNest."
    }
}

@MainActor
enum PasteboardService {
    static func copy(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw PasteboardError.copyFailed
        }
    }
}
