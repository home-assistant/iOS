import SwiftUI

public struct HAProgressView: View {
    public enum Style {
        /// A style intended for pull-to-refresh indicators. It has a fixed size of 24x24 points,
        /// includes padding, a white background, and is clipped to a circular shape.
        case refreshControl
        case small
        case medium
        case large
        case extraLarge

        var size: CGSize {
            switch self {
            case .small, .refreshControl:
                return CGSize(width: 24, height: 24)
            case .medium:
                return CGSize(width: 28, height: 28)
            case .large:
                return CGSize(width: 48, height: 48)
            case .extraLarge:
                return CGSize(width: 68, height: 68)
            }
        }

        var lineWidth: CGFloat {
            4
        }
    }

    @State private var isAnimating = false
    @State private var trimEnd: CGFloat = 0.0

    let style: Style

    public init(style: Style = .medium) {
        self.style = style
    }

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
        .padding(style == .refreshControl ? Spaces.one : 0)
        .background(backgroundColor)
        .modify { view in
            if style == .refreshControl {
                view.clipShape(Circle())
            } else {
                view
            }
        }
    }

    private var backgroundColor: Color {
        if style == .refreshControl {
            #if !os(watchOS)
            Color(uiColor: .systemBackground)
            #else
            Color.white
            #endif
        } else {
            Color.clear
        }
    }
}

#Preview {
    HStack(spacing: Spaces.two) {
        HAProgressView(style: .small)
        HAProgressView(style: .medium)
        HAProgressView(style: .large)
        HAProgressView(style: .extraLarge)
    }
}
