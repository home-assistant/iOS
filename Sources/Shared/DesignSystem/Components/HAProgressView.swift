import SwiftUI

public struct HAProgressView: View {
    public enum Style {
        case small
        case medium

        var size: CGSize {
            switch self {
            case .small:
                return CGSize(width: 40, height: 40)
            case .medium:
                return CGSize(width: 60, height: 60)
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .small:
                return 5
            case .medium:
                return 7
            }
        }
    }

    @State private var isAnimating = false
    @State private var trimEnd: CGFloat = 0.0

    let style: Style

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.track, style: StrokeStyle(lineWidth: style.lineWidth))
                .frame(width: style.size.width, height: style.size.height)
            Circle()
                .trim(from: 0.0, to: trimEnd)
                .stroke(
                    Color.haPrimary,
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                )
                .frame(width: style.size.width, height: style.size.height)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                    withAnimation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true)) {
                        trimEnd = 0.7
                    }
                }
        }
    }
}

#Preview {
    HStack(spacing: Spaces.two) {
        HAProgressView(style: .small)
        HAProgressView(style: .medium)
    }
}
