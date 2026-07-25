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

    // Launch animation state (§Task 2)
    @State private var titleOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 20
    @State private var cardsOpacity: Double = 0

    var body: some View {
        ZStack {
            // Parallax background
            ParallaxGridBackground()
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                Spacer()

                // FORGE Title — fade-in on appear
                forgeTitle
                    .opacity(titleOpacity)

                Spacer()
                    .frame(height: 48)

                // Mode Cards — slide-up on appear
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
                .opacity(cardsOpacity)
                .offset(y: cardsOffset)

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
            // Staggered launch animation: title fades in, then cards slide up.
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    titleOpacity = 1
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                    cardsOffset = 0
                    cardsOpacity = 1
                }
            }
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
                switch mode {
                case .onDevice:
                    BuildOnDeviceScreen()
                        .environmentObject(appState)
                case .missionControl:
                    MissionControlScreen()
                }
            }
        }
    }

    // MARK: - FORGE Title

    private var forgeTitle: some View {
        VStack(spacing: 0) {
            Text("FORGE")
                .font(.forgeTitle)
                .foregroundStyle(SwiftUI.Color.forgePrimaryText)
                .tracking(4)

            // Cyan underline
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            SwiftUI.Color.forgeAccent.opacity(0),
                            SwiftUI.Color.forgeAccent,
                            SwiftUI.Color.forgeAccent.opacity(0)
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
            .foregroundStyle(SwiftUI.Color.forgeAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: ForgeMetrics.smallCornerRadius, style: .continuous)
                    .stroke(SwiftUI.Color.forgeBorder, lineWidth: 1)
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
                    .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

                Text(label)
                    .font(.forgeMicro)
                    .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
            }
            .frame(width: 64, height: 48)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(label)
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
            SwiftUI.Color.forgeBackground.ignoresSafeArea()

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
                        .foregroundStyle(SwiftUI.Color.forgeAccent)
                        .forgeGlow(radius: 16)

                    Text(mode.rawValue)
                        .font(.forgeHeadline)
                        .foregroundStyle(SwiftUI.Color.forgePrimaryText)
                        .tracking(2)

                    Text(mode.subtitle)
                        .font(.forgeBody)
                        .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    if let project = appState.currentProject {
                        Divider()
                            .frame(width: 200)
                            .background(SwiftUI.Color.forgeBorder)

                        VStack(spacing: 4) {
                            Text("Active Project")
                                .font(.forgeMicro)
                                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)

                            Text(project.name)
                                .font(.forgeBodyMono)
                                .foregroundStyle(SwiftUI.Color.forgeAccent)
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
