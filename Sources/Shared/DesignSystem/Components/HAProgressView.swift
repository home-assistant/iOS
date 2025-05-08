import SwiftUI

struct HAProgressView: View {
    enum Style {
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
    let style: Style

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .secondarySystemBackground), style: StrokeStyle(lineWidth: style.lineWidth))
                .frame(width: style.size.width, height: style.size.height)
            Circle()
                .trim(from: 0.0, to: 0.7)
                .stroke(
                    Color.asset(Asset.Colors.haPrimary),
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                )
                .frame(width: style.size.width, height: style.size.height)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
        }
    }
}

#Preview {
    HStack {
        HAProgressView(style: .small)
        HAProgressView(style: .medium)
    }
}
