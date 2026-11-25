import Foundation

struct UserError: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(title: String = "Something Went Wrong", error: Error) {
        self.title = title

        guard let localizedError = error as? LocalizedError else {
            message = error.localizedDescription
            return
        }

        let parts = [
            localizedError.errorDescription,
            localizedError.failureReason,
            localizedError.recoverySuggestion
        ]
        .compactMap { $0 }
        .reduce(into: [String]()) { result, part in
            if !result.contains(part) {
                result.append(part)
            }
        }

        message = parts.isEmpty ? error.localizedDescription : parts.joined(separator: "\n\n")
    }
}
