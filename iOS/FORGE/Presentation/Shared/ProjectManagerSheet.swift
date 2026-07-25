import SwiftUI

// MARK: - Project Manager Sheet

/// Sheet for listing, creating, opening, and deleting projects.
/// Projects are stored on disk under Documents/projects/ with metadata
/// persisted via AppState (UserDefaults).
///
/// Per spec section 15: Project management interface.
struct ProjectManagerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateSheet = false
    @State private var newProjectName = ""
    @State private var newProjectLanguage = "Swift"
    @State private var newProjectFramework = "SwiftUI"
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if filteredProjects.isEmpty && searchText.isEmpty {
                    emptyState
                } else if filteredProjects.isEmpty {
                    noSearchResults
                } else {
                    projectList
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search projects")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        ForgeHaptic.impact(.light)
                        showingCreateSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SwiftUI.Color.forgeBackground)
            .tint(.forgeAccent)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCreateSheet) {
            createProjectSheet
        }
    }

    // MARK: - Filtered Projects

    private var filteredProjects: [ForgeProject] {
        if searchText.isEmpty {
            return appState.projects
        }
        return appState.projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.language.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

            VStack(spacing: 8) {
                Text("No Projects Yet")
                    .font(.forgeHeadline)
                    .foregroundStyle(SwiftUI.Color.forgePrimaryText)

                Text("Create your first project to get started")
                    .font(.forgeBody)
                    .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                ForgeHaptic.impact(.medium)
                showingCreateSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Project")
                }
                .font(.forgeBodyMono)
                .foregroundStyle(SwiftUI.Color.forgeBackground)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(SwiftUI.Color.forgeAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - No Search Results

    private var noSearchResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

            Text("No projects found")
                .font(.forgeBody)
                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

            Text("Try a different search term")
                .font(.forgeCaption)
                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Project List

    private var projectList: some View {
        List {
            ForEach(filteredProjects) { project in
                Button(action: {
                    ForgeHaptic.impact(.medium)
                    appState.openProject(project)
                    dismiss()
                }) {
                    ProjectRow(project: project)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(SwiftUI.Color.forgeSurface)
                .listRowSeparatorTint(SwiftUI.Color.forgeBorder)
                .padding(.vertical, 2)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let project = filteredProjects[index]
                    ForgeHaptic.notify(.warning)
                    appState.deleteProject(project)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Create Project Sheet

    private var createProjectSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $newProjectName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Language", selection: $newProjectLanguage) {
                        ForEach(supportedLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .onChange(of: newProjectLanguage) { _, newValue in
                        // Auto-select a reasonable framework for the language
                        if let defaultFW = defaultFramework(for: newValue) {
                            newProjectFramework = defaultFW
                        }
                    }

                    Picker("Framework", selection: $newProjectFramework) {
                        ForEach(frameworks(for: newProjectLanguage), id: \.self) { fw in
                            Text(fw).tag(fw)
                        }
                    }
                } header: {
                    Text("Project Details")
                }

                Section {
                    Button(action: createProject) {
                        HStack {
                            Image(systemName: "folder.fill.badge.plus")
                            Text("Create Project")
                        }
                        .foregroundStyle(SwiftUI.Color.forgeSuccess)
                        .fontWeight(.medium)
                    }
                    .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateSheet = false
                        resetForm()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SwiftUI.Color.forgeBackground)
            .tint(.forgeAccent)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Language / Framework Helpers

    private let supportedLanguages = [
        "Swift", "TypeScript", "Python", "Rust", "Go", "JavaScript"
    ]

    private func frameworks(for language: String) -> [String] {
        switch language {
        case "Swift":       return ["SwiftUI", "UIKit", "Vapor", "None"]
        case "TypeScript":  return ["React", "Vue", "Next.js", "Express", "None"]
        case "Python":      return ["FastAPI", "Django", "Flask", "None"]
        case "Rust":        return ["Actix", "Axum", "Tauri", "None"]
        case "Go":          return ["Gin", "Echo", "Fiber", "None"]
        case "JavaScript":  return ["React", "Vue", "Express", "None"]
        default:            return ["None"]
        }
    }

    private func defaultFramework(for language: String) -> String? {
        frameworks(for: language).first
    }

    // MARK: - Actions

    private func createProject() {
        let trimmedName = newProjectName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            ForgeHaptic.notify(.warning)
            return
        }

        // Check for duplicate
        if appState.projects.contains(where: { $0.name == trimmedName }) {
            ForgeHaptic.notify(.error)
            return
        }

        let project = appState.createProject(
            name: trimmedName,
            language: newProjectLanguage,
            framework: newProjectFramework
        )

        resetForm()
        showingCreateSheet = false
        ForgeHaptic.notify(.success)

        // Optionally dismiss and navigate
        appState.openProject(project)
        dismiss()
    }

    private func resetForm() {
        newProjectName = ""
        newProjectLanguage = "Swift"
        newProjectFramework = "SwiftUI"
    }
}

// MARK: - Project Row

/// A row displaying a single project in the list.
struct ProjectRow: View {
    let project: ForgeProject

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Language icon
            Image(systemName: languageIcon)
                .font(.system(size: 24))
                .foregroundStyle(SwiftUI.Color.forgeAccent)
                .frame(width: 36, height: 36)

            // Project info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.forgeBodyMono)
                    .foregroundStyle(SwiftUI.Color.forgePrimaryText)

                HStack(spacing: 6) {
                    Text(project.language)
                        .font(.forgeMicro)
                        .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

                    Text("•")
                        .font(.forgeMicro)
                        .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

                    Text(project.framework)
                        .font(.forgeMicro)
                        .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
                }
            }

            Spacer()

            // Last accessed
            VStack(alignment: .trailing, spacing: 2) {
                Text(project.lastAccessed, style: .relative)
                    .font(.forgeMicro)
                    .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

                Text("ago")
                    .font(.forgeMicro)
                    .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
            }
        }
        .padding(.vertical, 6)
    }

    private var languageIcon: String {
        switch project.language {
        case "Swift":       return "swift"
        case "TypeScript":  return "curlybraces"
        case "JavaScript":  return "curlybraces"
        case "Python":      return "chevron.left.forwardslash.chevron.right"
        case "Rust":        return "hammer"
        case "Go":          return "shippingbox"
        default:            return "folder"
        }
    }
}

// MARK: - Preview

#Preview("Empty State") {
    ProjectManagerSheet()
        .environmentObject(AppState())
}

#Preview("With Projects") {
    ProjectManagerSheet()
        .environmentObject({
            let state = AppState()
            state.projects = [
                ForgeProject(name: "MyApp", path: "/test", language: "Swift", framework: "SwiftUI"),
                ForgeProject(name: "API", path: "/test", language: "Python", framework: "FastAPI"),
            ]
            return state
        }())
}
