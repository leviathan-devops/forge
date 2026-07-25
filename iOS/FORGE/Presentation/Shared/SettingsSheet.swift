import SwiftUI

// MARK: - Settings Sheet

/// Configuration sheet for API provider, API key, model selection,
/// Git user info, and app information.
///
/// Per spec section 21: Settings with Keychain-backed API key storage.
struct SettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Local editing state (committed on Save)
    @State private var apiProvider: APIProvider = .anthropic
    @State private var apiKey: String = ""
    @State private var modelName: String = ""
    @State private var gitUserName: String = ""
    @State private var gitUserEmail: String = ""

    @State private var showSaveAlert = false
    @State private var hasUnsavedChanges = false

    var body: some View {
        NavigationStack {
            Form {
                apiConfigurationSection
                gitConfigurationSection
                actionsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        if hasUnsavedChanges {
                            showSaveAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.forgeBackground)
            .tint(.forgeAccent)
        }
        .preferredColorScheme(.dark)
        .onAppear { syncFromAppState() }
        .alert("Save Changes?", isPresented: $showSaveAlert) {
            Button("Save") { saveSettings(); dismiss() }
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Would you like to save before closing?")
        }
    }

    // MARK: - API Configuration Section

    private var apiConfigurationSection: some View {
        Section {
            // Provider picker
            Picker("Provider", selection: $apiProvider) {
                ForEach(APIProvider.allCases) { provider in
                    Label(provider.rawValue, systemImage: provider.icon)
                        .tag(provider)
                }
            }
            .onChange(of: apiProvider) { _, newValue in
                if modelName.isEmpty || modelName == apiProvider.defaultModel {
                    modelName = newValue.defaultModel
                }
                hasUnsavedChanges = true
            }

            // API Key (only for providers that need it)
            if apiProvider.requiresAPIKey {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: apiKey) { _, _ in hasUnsavedChanges = true }
            }

            // Model name
            HStack {
                Text("Model")
                    .foregroundStyle(Color.forgePrimaryText)
                Spacer()
                TextField("model-name", text: $modelName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.forgeSecondaryText)
                    .font(.forgeBodyMono)
                    .onChange(of: modelName) { _, _ in hasUnsavedChanges = true }
            }

            // Reset to default model
            Button(action: {
                ForgeHaptic.selection()
                modelName = apiProvider.defaultModel
                hasUnsavedChanges = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Default Model")
                }
                .font(.forgeCaption)
                .foregroundStyle(Color.forgeAccent)
            }
        } header: {
            sectionHeader("API CONFIGURATION", icon: "brain.head.profile")
        }
    }

    // MARK: - Git Configuration Section

    private var gitConfigurationSection: some View {
        Section {
            TextField("User Name", text: $gitUserName)
                .textInputAutocapitalization(.words)
                .onChange(of: gitUserName) { _, _ in hasUnsavedChanges = true }

            TextField("User Email", text: $gitUserEmail)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .onChange(of: gitUserEmail) { _, _ in hasUnsavedChanges = true }
        } header: {
            sectionHeader("GIT CONFIGURATION", icon: "arrow.triangle.branch")
        } footer: {
            Text("Used for commit authorship in Git operations.")
                .font(.forgeMicro)
                .foregroundStyle(Color.forgeSecondaryText)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button(action: saveSettings) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Settings")
                }
                .foregroundStyle(Color.forgeSuccess)
                .fontWeight(.medium)
            }

            if hasUnsavedChanges {
                Button(role: .destructive, action: resetChanges) {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Discard Changes")
                    }
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            aboutRow(label: "Version", value: appVersion)
            aboutRow(label: "Build", value: appBuild)
            aboutRow(label: "Engine", value: "SwiftUI + SwiftTerm")
            aboutRow(label: "Min iOS", value: "17.0")

            Divider()

            Link(destination: URL(string: "https://github.com")!) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Documentation")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.forgeAccent)
            }

            Link(destination: URL(string: "https://github.com")!) {
                HStack {
                    Image(systemName: "exclamationmark.bubble.fill")
                    Text("Report an Issue")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.forgeAccent)
            }
        } header: {
            sectionHeader("ABOUT", icon: "info.circle")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(title)
        }
        .font(.forgeMicro)
        .foregroundStyle(Color.forgeSecondaryText)
        .tracking(0.5)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.forgePrimaryText)
            Spacer()
            Text(value)
                .foregroundStyle(Color.forgeSecondaryText)
                .font(.forgeBodyMono)
        }
    }

    // MARK: - State Sync

    private func syncFromAppState() {
        apiProvider = appState.apiProvider
        apiKey = appState.apiKey
        modelName = appState.modelName
        gitUserName = appState.gitUserName
        gitUserEmail = appState.gitUserEmail
        hasUnsavedChanges = false
    }

    private func saveSettings() {
        appState.apiProvider = apiProvider
        appState.apiKey = apiKey
        appState.modelName = modelName
        appState.gitUserName = gitUserName
        appState.gitUserEmail = gitUserEmail
        appState.saveSettings()

        ForgeHaptic.notify(.success)
        hasUnsavedChanges = false
    }

    private func resetChanges() {
        ForgeHaptic.selection()
        syncFromAppState()
    }
}

// MARK: - Preview

#Preview {
    SettingsSheet()
        .environmentObject(AppState())
}
