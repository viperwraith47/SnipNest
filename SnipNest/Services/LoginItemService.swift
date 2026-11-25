import ServiceManagement

enum LoginItemError: LocalizedError {
    case updateFailed(String)

    var errorDescription: String? {
        "SnipNest couldn’t update Launch at Login."
    }

    var failureReason: String? {
        switch self {
        case .updateFailed(let reason):
            reason
        }
    }

    var recoverySuggestion: String? {
        "Check SnipNest in System Settings > General > Login Items & Extensions, then try again."
    }
}

@MainActor
enum LoginItemService {
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .notFound:
            false
        @unknown default:
            false
        }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> Bool {
        do {
            if enabled {
                switch SMAppService.mainApp.status {
                case .notRegistered, .notFound:
                    try SMAppService.mainApp.register()
                case .enabled, .requiresApproval:
                    break
                @unknown default:
                    break
                }
            } else if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw LoginItemError.updateFailed(error.localizedDescription)
        }

        return SMAppService.mainApp.status == .requiresApproval
    }
}
