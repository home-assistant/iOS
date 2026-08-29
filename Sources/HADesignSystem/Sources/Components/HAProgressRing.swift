#if !os(watchOS)
import SwiftUI

/// A circular progress indicator, either showing a known fraction or spinning while work runs. The
/// SwiftUI counterpart of the frontend's `ha-progress-ring`.
public struct HAProgressRing: View {
    /// The four sizes `ha-progress-ring` exposes, in the points it sets `--ha-progress-ring-size` to.
    public enum Size: CGFloat, CaseIterable, Sendable {
        case tiny = 16
        case small = 28
        case medium = 48
        case large = 68
    }

    private let value: Double?
    private let size: Size

    /// - Parameter value: The fraction filled, `0...1`. Pass `nil` for the indeterminate ring, which
    ///   spins a fixed arc instead — the frontend's default when no value is set.
    public init(value: Double? = nil, size: Size = .medium) {
        self.value = value
        self.size = size
    }

    /// `--track-width: 4px` in the frontend, at its 48px default. Scaled so a tiny ring keeps its
    /// proportions rather than being mostly stroke.
    private var lineWidth: CGFloat {
        4 * (size.rawValue / Size.medium.rawValue)
    }

    /// Without a value there is nothing to draw an arc against, so the ring hands off to
    /// ``HAProgressView`` — the package's spinner, which already draws its own track. Nesting one
    /// inside this ring's track would show two concentric circles.
    private var spinnerStyle: HAProgressView.Style {
        switch size {
        case .tiny: .small
        case .small: .medium
        case .medium: .large
        case .large: .extraLarge
        }
    }

    public var body: some View {
        if let value {
            ZStack {
                Circle()
                    .stroke(Color.haDivider, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: value.clampedToUnitInterval)
                    .stroke(Color.haPrimary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    // Start at twelve o'clock rather than three, which is where `trim` begins.
                    .rotationEffect(.degrees(-90))
            }
            .padding(lineWidth / 2)
            .frame(width: size.rawValue, height: size.rawValue)
            .accessibilityElement()
            .accessibilityValue(Text(value.clampedToUnitInterval, format: .percent.precision(.fractionLength(0))))
        } else {
            HAProgressView(style: spinnerStyle)
        }
    }
}

private extension Double {
    var clampedToUnitInterval: Double {
        Swift.min(Swift.max(self, 0), 1)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HStack(spacing: DesignSystem.Spaces.two) {
            ForEach(HAProgressRing.Size.allCases, id: \.rawValue) { size in
                HAProgressRing(value: 0.65, size: size)
            }
        }
        HAProgressRing(value: 0)
        HAProgressRing(value: 1)
        HAProgressRing()
    }
    .padding()
}

extension HAProgressRing: FrontendComponent {
    public static var frontendComponentName: String { "ha-progress-ring" }
}

#endif
