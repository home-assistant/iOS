#if !os(watchOS)
import SwiftUI

/// A pill-shaped progress bar, either showing a known fraction or waiting on work of unknown length.
/// The SwiftUI counterpart of the frontend's `progress/ha-progress-bar`.
///
/// Distinct from ``HABar``, which is `ha-bar`: that one is a *reading* — how full a tank is — with a
/// squarer radius and no indeterminate form. This one reports progress.
public struct HAProgressBar: View {
    private let value: Double?
    private let tint: Color

    /// - Parameter value: The fraction complete, `0...1`. Pass `nil` when the length is unknown; the
    ///   bar then defers to the platform's indeterminate style rather than animating its own, since
    ///   a continuous animation cannot be captured the same way twice.
    public init(value: Double? = nil, tint: Color = .haPrimary) {
        self.value = value
        self.tint = tint
    }

    private static let height: CGFloat = 12

    public var body: some View {
        if let value {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.haDisabled.opacity(0.2))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * Swift.min(Swift.max(value, 0), 1))
                }
            }
            .frame(height: Self.height)
            .accessibilityElement()
            .accessibilityValue(
                Text(Swift.min(Swift.max(value, 0), 1), format: .percent.precision(.fractionLength(0)))
            )
        } else {
            ProgressView()
                .progressViewStyle(.linear)
                .tint(tint)
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAProgressBar(value: 0)
        HAProgressBar(value: 0.35)
        HAProgressBar(value: 1)
        HAProgressBar(value: 1.4)
        HAProgressBar(value: 0.6, tint: .haSuccessColor)
    }
    .padding()
}

extension HAProgressBar: FrontendComponent {
    public static var frontendComponentName: String { "ha-progress-bar" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
