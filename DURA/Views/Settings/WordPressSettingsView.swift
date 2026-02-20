import SwiftUI

struct WordPressSettingsView: View {
    @State private var siteURL = ""
    @State private var username = ""
    @State private var appPassword = ""
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSuccess = false

    private let store = WordPressCredentialStore()

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Site URL", text: $siteURL, prompt: Text("https://yoursite.com"))
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif

                TextField("Username", text: $username)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif

                SecureField("Application Password", text: $appPassword)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(siteURL.isEmpty || username.isEmpty || appPassword.isEmpty || isTesting)

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let testResult {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(testSuccess ? .green : .red)
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(testSuccess ? .green : .red)
                    }
                }
            }

            Section {
                HStack {
                    Button("Save Credentials") {
                        saveCredentials()
                    }
                    .disabled(siteURL.isEmpty || username.isEmpty || appPassword.isEmpty)

                    Button("Clear Credentials", role: .destructive) {
                        clearCredentials()
                    }
                }
            }

            Section {
                Text("WordPress Application Passwords are required for authentication. Generate one in your WordPress admin under Users > Profile > Application Passwords.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            loadCredentials()
        }
    }

    private func loadCredentials() {
        if let config = store.load() {
            siteURL = config.siteURL
            username = config.username
            appPassword = config.appPassword
        }
    }

    private func saveCredentials() {
        let config = WordPressConfig(
            siteURL: siteURL,
            username: username,
            appPassword: appPassword
        )
        do {
            try store.save(config)
            testResult = "Saved"
            testSuccess = true
        } catch {
            testResult = error.localizedDescription
            testSuccess = false
        }
    }

    private func clearCredentials() {
        store.delete()
        siteURL = ""
        username = ""
        appPassword = ""
        testResult = nil
    }

    private func testConnection() {
        let config = WordPressConfig(
            siteURL: siteURL,
            username: username,
            appPassword: appPassword
        )

        isTesting = true
        testResult = nil

        Task {
            do {
                let service = WordPressService()
                try await service.validateConnection(config: config)
                isTesting = false
                testResult = "Connection successful"
                testSuccess = true
            } catch {
                isTesting = false
                testResult = error.localizedDescription
                testSuccess = false
            }
        }
    }
}
