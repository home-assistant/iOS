#if !os(watchOS)
import HAIconic
import SwiftUI

/// A button that reports the outcome of what it started: a spinner while the work runs, then a check
/// or a warning. The SwiftUI counterpart of the frontend's `ha-progress-button`.
///
/// The label stays in place under the spinner and result icons at zero opacity rather than being
/// swapped out, so the button keeps its accessible name and its width does not jump between states —
/// the frontend fades its parts for the same reason.
public struct HAProgressButton: View {
    private let title: String
    private let icon: MaterialDesignIcons?
    private let state: HAProgressButtonState
    private let action: () -> Void

    public init(
        _ title: String,
        icon: MaterialDesignIcons? = nil,
        state: HAProgressButtonState = .idle,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spaces.one) {
                if let icon {
                    MaterialDesignIconsImage(icon: icon, size: 18)
                }
                Text(title)
            }
            .opacity(state == .idle ? 1 : 0)
            .overlay {
                switch state {
                case .idle:
                    EmptyView()
                case .inProgress:
                    HAProgressView(style: .small, colorType: .light)
                case .success:
                    MaterialDesignIconsImage(icon: .checkBoldIcon, size: 20)
                case .failure:
                    MaterialDesignIconsImage(icon: .alertOctagramIcon, size: 20)
                }
            }
        }
        .buttonStyle(.primaryButton(fill: resultTint))
        // A button mid-flight must not be pressed again. `allowsHitTesting` rather than `disabled`,
        // because disabling greys the fill out and the spinner would then sit on a dead-looking
        // button — the frontend drops pointer events for the same reason.
        .allowsHitTesting(state != .inProgress)
        .accessibilityLabel(Text(title))
    }

    /// The frontend recolours the whole button to carry the result, rather than only the icon.
    private var resultTint: Color {
        switch state {
        case .idle, .inProgress: .haPrimary
        case .success: .haSuccessColor
        case .failure: .haErrorColor
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        ForEach(HAProgressButtonState.allCases, id: \.rawValue) { state in
            HAProgressButton("Send", icon: .sendIcon, state: state) {}
        }
    }
    .padding()
}

extension HAProgressButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-progress-button" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
