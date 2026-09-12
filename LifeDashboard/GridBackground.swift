import SwiftUI

/// The faint graph-paper texture used throughout the app, echoing the app
/// icon's grid motif. Drawn with Canvas rather than a tiled image so it
/// scales cleanly to any screen size with no asset needed.
private struct GridTexture: View {
    var spacing: CGFloat = 28
    var lineColor: Color = ClaudeTheme.border
    var lineOpacity: Double = 0.3

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct GridBackground: View {
    var body: some View {
        ZStack {
            ClaudeTheme.background
            GridTexture()
        }
        .ignoresSafeArea()
    }
}
