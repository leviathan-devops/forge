import SwiftUI
import CoreMotion

// MARK: - Parallax Grid Background

/// A subtle animated grid background that responds to device tilt via CoreMotion.
/// Renders a 40pt grid at 3% opacity with a maximum 10pt parallax offset.
///
/// Per spec section 17: Parallax grid background for the launch menu.
struct ParallaxGridBackground: View {
    @State private var xOffset: CGFloat = 0
    @State private var yOffset: CGFloat = 0

    /// Must be @State so SwiftUI persists the same CMMotionManager across
    /// body recomputations. Without @State, SwiftUI recreates the struct on
    /// every parent body evaluation, allocating a new CMMotionManager each
    /// time. The onDisappear closure would then call stopDeviceMotionUpdates
    /// on a DIFFERENT instance than the one that started updates — leaving
    /// the original manager running forever (battery drain).
    @State private var motionManager = CMMotionManager()
    private let gridSize: CGFloat = ForgeMetrics.gridSize           // 40pt
    private let maxOffset: CGFloat = ForgeMetrics.maxParallaxOffset // 10pt
    private let gridOpacity: Double = ForgeMetrics.gridOpacity      // 0.03

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid background
                SwiftUI.Color.forgeBackground

                // Subtle radial glow at center-top
                RadialGradient(
                    colors: [
                        SwiftUI.Color.forgeAccent.opacity(0.04),
                        SwiftUI.Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.6
                )

                // Parallax grid
                Canvas { context, size in
                    drawGrid(in: context, size: size)
                }
                .offset(x: xOffset, y: yOffset)
            }
        }
        .onAppear {
            startMotionUpdates()
        }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    // MARK: - Grid Drawing

    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        var path = Path()

        // Vertical lines
        var x: CGFloat = -maxOffset
        while x <= size.width + maxOffset {
            path.move(to: CGPoint(x: x, y: -maxOffset))
            path.addLine(to: CGPoint(x: x, y: size.height + maxOffset))
            x += gridSize
        }

        // Horizontal lines
        var y: CGFloat = -maxOffset
        while y <= size.height + maxOffset {
            path.move(to: CGPoint(x: -maxOffset, y: y))
            path.addLine(to: CGPoint(x: size.width + maxOffset, y: y))
            y += gridSize
        }

        context.stroke(
            path,
            with: .color(.white.opacity(gridOpacity)),
            lineWidth: 1
        )
    }

    // MARK: - CoreMotion

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { motionData, error in
            guard let data = motionData, error == nil else { return }

            let gravity = data.gravity

            // Invert X for natural tilt direction, clamp to maxOffset
            let newX = min(max(CGFloat(-gravity.x) * self.maxOffset, -self.maxOffset), self.maxOffset)
            let newY = min(max(CGFloat(gravity.y) * self.maxOffset, -self.maxOffset), self.maxOffset)

            withAnimation(.linear(duration: 0.1)) {
                self.xOffset = newX
                self.yOffset = newY
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ParallaxGridBackground()
        .ignoresSafeArea()
}
