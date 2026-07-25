import SwiftUI

// MARK: - Launch Menu View

/// The main launch menu screen.
///
/// Displays the FORGE title with cyan underline, two mode selection cards,
/// a "Continue Last Session" button (when applicable), and footer icons
/// for settings and project management.
///
/// Uses `fullScreenCover` for mode transitions per spec section 17.
struct LaunchMenuView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedCardMode: ForgeMode?

    var body: some View {
        ZStack {
            // Parallax background
            ParallaxGridBackground()
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                Spacer()

                // FORGE Title
                forgeTitle

                Spacer()
                    .frame(height: 48)

                // Mode Cards
                VStack(spacing: 16) {
                    ForEach(ForgeMode.allCases, id: \.self) { mode in
                        ModeCard(
                            mode: mode,
                            isSelected: Binding(
                                get: { selectedCardMode == mode },
                                set: { newValue in
                                    if newValue { selectedCardMode = mode }
                                }
                            ),
                            action: {
                                appState.selectMode(mode)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 24)

                // Continue Last Session
                if appState.lastSession != nil {
                    continueSessionButton
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Footer
                footerBar
                    .padding(.bottom, 32)
            }
            .padding(.horizontal)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { appState.selectedMode != nil && !appState.showingLaunchMenu },
                set: { newValue in
                    if !newValue {
                        appState.returnToLaunchMenu()
                        selectedCardMode = nil
                    }
                }
            )
        ) {
            if let mode = appState.selectedMode {
                ModePlaceholderView(mode: mode)
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - FORGE Title

    private var forgeTitle: some View {
        VStack(spacing: 0) {
            Text("FORGE")
                .font(.forgeTitle)
                .foregroundStyle(Color.forgePrimaryText)
                .tracking(4)

            // Cyan underline
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.forgeAccent.opacity(0),
                            Color.forgeAccent,
                            Color.forgeAccent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: ForgeMetrics.titleUnderlineWidth, height: ForgeMetrics.titleUnderlineHeight)
                .padding(.top, 12)
                .forgeGlow()
        }
    }

    // MARK: - Continue Session Button

    private var continueSessionButton: some View {
        Button(action: {
            appState.continueLastSession()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))

                if let session = appState.lastSession {
                    Text("Continue: \(session.title)")
                        .font(.forgeBodyMono)
                        .lineLimit(1)
                } else {
                    Text("Continue Last Session")
                        .font(.forgeBodyMono)
                }
            }
            .foregroundStyle(Color.forgeAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: ForgeMetrics.smallCornerRadius, style: .continuous)
                    .stroke(Color.forgeBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 24) {
            footerButton(
                icon: "gearshape.fill",
                label: "Settings",
                action: { appState.showingSettings = true }
            )

            footerButton(
                icon: "folder.fill",
                label: "Projects",
                action: { appState.showingProjectManager = true }
            )
        }
    }

    private func footerButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            ForgeHaptic.impact(.light)
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.forgeSecondaryText)

                Text(label)
                    .font(.forgeMicro)
                    .foregroundStyle(Color.forgeSecondaryText)
            }
            .frame(width: 64, height: 48)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Mode Placeholder View

/// Placeholder view shown when a mode is selected.
/// This will be replaced by full mode implementations in subsequent build phases.
struct ModePlaceholderView: View {
    let mode: ForgeMode
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.forgeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                TopBar(
                    title: mode.rawValue,
                    onBack: { appState.returnToLaunchMenu() },
                    rightIcon: "gearshape",
                    rightLabel: "Settings",
                    onRightTap: { appState.showingSettings = true }
                )

                Spacer()

                // Mode content placeholder
                VStack(spacing: 20) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Color.forgeAccent)
                        .forgeGlow(radius: 16)

                    Text(mode.rawValue)
                        .font(.forgeHeadline)
                        .foregroundStyle(Color.forgePrimaryText)
                        .tracking(2)

                    Text(mode.subtitle)
                        .font(.forgeBody)
                        .foregroundStyle(Color.forgeSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    if let project = appState.currentProject {
                        Divider()
                            .frame(width: 200)
                            .background(Color.forgeBorder)

                        VStack(spacing: 4) {
                            Text("Active Project")
                                .font(.forgeMicro)
                                .foregroundStyle(Color.forgeSecondaryText)

                            Text(project.name)
                                .font(.forgeBodyMono)
                                .foregroundStyle(Color.forgeAccent)
                        }
                    }
                }

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    LaunchMenuView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
