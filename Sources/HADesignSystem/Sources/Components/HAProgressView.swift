import SwiftUI

public struct HAProgressView: View {
    private enum Constants {
        static let rotationDuration: TimeInterval = 1
        static let trimDuration: TimeInterval = 1.75
        static let minimumTrim: CGFloat = 0.1
        static let maximumTrim: CGFloat = 0.7
    }

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

    let style: Style
    let colorType: ColorType

    public init(style: Style = .medium, colorType: ColorType = .default) {
        self.style = style
        self.colorType = colorType
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                Circle()
                    .stroke(
                        colorType == .default ? Color.track : Color.white,
                        style: StrokeStyle(lineWidth: style.lineWidth)
                    )
                    .frame(width: style.size.width, height: style.size.height)
                Circle()
                    .trim(from: 0, to: trimEnd(for: timeline.date))
                    .stroke(
                        Color.haPrimary.opacity(colorType == .default ? 1 : 0.5),
                        style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                    )
                    .frame(width: style.size.width, height: style.size.height)
                    .rotationEffect(Angle(degrees: rotationDegrees(for: timeline.date)))
            }
        }
        .frame(width: style.size.width, height: style.size.height, alignment: .center)
    }

    private func rotationDegrees(for date: Date) -> CGFloat {
        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Constants.rotationDuration) / Constants.rotationDuration
        return progress * 360
    }

    private func trimEnd(for date: Date) -> CGFloat {
        let cycleDuration = Constants.trimDuration * 2
        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration) / Constants.trimDuration
        let autoreversingProgress = progress <= 1 ? progress : 2 - progress
        let easedProgress = 0.5 - cos(autoreversingProgress * .pi) / 2
        return Constants.minimumTrim + (Constants.maximumTrim - Constants.minimumTrim) * CGFloat(easedProgress)
    }
}

#Preview("In HStack") {
    HStack(spacing: DesignSystem.Spaces.two) {
        HAProgressView(style: .small)
        HAProgressView(style: .medium)
        HAProgressView(style: .large)
        HAProgressView(style: .extraLarge)
    }
}

#Preview("In List") {
    List {
        HAProgressView(style: .small)
        HAProgressView(style: .medium)
        HAProgressView(style: .large)
        HAProgressView(style: .extraLarge)
    }
}

#Preview("In VStack") {
    VStack {
        HAProgressView(style: .small)
        HAProgressView(style: .medium)
        HAProgressView(style: .large)
        HAProgressView(style: .extraLarge)
    }
}

#Preview("In Navigation view small") {
    NavigationView {
        HAProgressView(style: .small)
    }
}

#Preview("In Navigation view medium") {
    NavigationView {
        HAProgressView(style: .medium)
    }
}

#Preview("In Navigation view large") {
    NavigationView {
        HAProgressView(style: .large)
    }
}

#Preview("In Navigation view extra lar") {
    NavigationView {
        HAProgressView(style: .extraLarge)
    }
}
