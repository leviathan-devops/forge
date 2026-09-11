import SwiftUI

// MARK: - Launch Menu View

/// The main launch menu screen.
///
/// Displays the FORGE title with accent underline, two mode selection cards,
/// a persistent "Continue last session" action, and a version-only footer
/// (spec §20.1).
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

                // Continue Last Session — persistent action (spec §20.1)
                continueSessionButton
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                Spacer()

                // Footer — version ONLY (spec §20.1)
                versionFooter
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
                        .environmentObject(appState)
                }
            }
        }
    }

    // MARK: - FORGE Title

    private var forgeTitle: some View {
        VStack(spacing: 0) {
            Text("FORGE")
                .font(.forgeMono(ForgeMetrics.titleFontSize, weight: .bold))
                .foregroundStyle(SwiftUI.Color.forgePrimaryText)
                .tracking(4)

            // Subheading (operator directive 2026-08-29): "Build Anything"
            // under the FORGE heading.
            Text("Build Anything")
                .font(.forgeMono(15, weight: .medium))
                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
                .tracking(5)
                .padding(.top, 10)

            // Accent underline
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

                Text("Continue last session")
                    .font(.forgeBodyMono)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
            }
            .foregroundStyle(SwiftUI.Color.forgeAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("continueLastSession")
    }

    // MARK: - Footer (version only — spec §20.1)

    /// App version read from the bundle. Footer shows ONLY this (no branding).
    private var appVersion: String {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return "v\(raw ?? "1.0.0")"
    }

    private var versionFooter: some View {
        Text(appVersion)
            .font(.forgeMicro)
            .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
    }
}

// MARK: - Preview

#Preview {
    LaunchMenuView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
