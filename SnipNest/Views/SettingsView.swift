import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.showMenuBarKey) private var showMenuBar = true
    @State private var launchAtLogin = false
    @State private var loginItemRequiresApproval = false
    @State private var presentedError: UserError?

    var body: some View {
        Form {
            Section {
                Toggle("Show Menu Bar Icon", isOn: $showMenuBar)
                    .accessibilityHint("Shows or hides the quick-copy SnipNest palette in the menu bar.")

                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: updateLaunchAtLogin
                    )
                )
                .accessibilityHint("Automatically starts SnipNest when you log in to this Mac.")

                if loginItemRequiresApproval {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("macOS requires approval before SnipNest can launch at login.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Login Items Settings") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                        .buttonStyle(.link)
                    }
                }
            } footer: {
                Text("You can still open SnipNest from the Dock when the menu bar icon is hidden.")
            }

            Section("Storage") {
                LabeledContent("Snippets") {
                    Text("On this Mac")
                }
                Text("SnipNest stores everything locally. It has no network access and does not collect analytics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .frame(width: 500, height: 340)
        .onAppear {
            launchAtLogin = LoginItemService.isEnabled
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            loginItemRequiresApproval = try LoginItemService.setEnabled(enabled)
            launchAtLogin = LoginItemService.isEnabled
        } catch {
            launchAtLogin = LoginItemService.isEnabled
            loginItemRequiresApproval = false
            presentedError = UserError(error: error)
        }
    }
}
