import SwiftUI

final class HAProgressViewModel: ObservableObject {
    @Published var isAnimating = false
    @Published var trimEnd: CGFloat = 0.1
}

public struct HAProgressView: View {
    public enum Style {
        case small
        case medium
        case large
        case extraLarge

        var size: CGSize {
            switch self {
            case .small:
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

    public enum ColorType {
        /// When display in light background
        case `default`
        /// When displayed on accented background such as haPrimary
        case light
    }

    @StateObject private var viewModel = HAProgressViewModel()
    let style: Style
    let colorType: ColorType

    public init(style: Style = .medium, colorType: ColorType = .default) {
        self.style = style
        self.colorType = colorType
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    colorType == .default ? Color.track : Color.white,
                    style: StrokeStyle(lineWidth: style.lineWidth)
                )
                .frame(width: style.size.width, height: style.size.height)
            Circle()
                .trim(from: 0, to: viewModel.trimEnd)
                .stroke(
                    Color.haPrimary.opacity(colorType == .default ? 1 : 0.5),
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                )
                .frame(width: style.size.width, height: style.size.height)
                .rotationEffect(Angle(degrees: viewModel.isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1).repeatForever(autoreverses: false),
                    value: viewModel.isAnimating
                )
                .onAppear {
                    viewModel.isAnimating = true
                    withAnimation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true)) {
                        viewModel.trimEnd = 0.7
                    }
                }
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
