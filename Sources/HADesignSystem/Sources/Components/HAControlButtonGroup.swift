#if !os(watchOS)
import SwiftUI

/// Lays out control buttons in a row or column, each taking an equal share. The SwiftUI counterpart
/// of the frontend's `ha-control-button-group`.
public struct HAControlButtonGroup<Content: View>: View {
    private let vertical: Bool
    private let thickness: CGFloat
    private let spacing: CGFloat
    private let content: Content

    /// - Parameter thickness: `--control-button-group-thickness`, the same 40pt a control button
    ///   is by default.
    public init(
        vertical: Bool = false,
        thickness: CGFloat = 40,
        spacing: CGFloat = DesignSystem.Spaces.oneAndHalf,
        @ViewBuilder content: () -> Content
    ) {
        self.vertical = vertical
        self.thickness = thickness
        self.spacing = spacing
        self.content = content()
    }

    private var layout: AnyLayout {
        vertical
            ? AnyLayout(VStackLayout(spacing: spacing))
            : AnyLayout(HStackLayout(spacing: spacing))
    }

    public var body: some View {
        layout {
            content
        }
        .frame(
            width: vertical ? thickness : nil,
            height: vertical ? nil : thickness
        )
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAControlButtonGroup {
            HAControlButton(icon: .powerIcon, label: "Toggle") {}
            HAControlButton(icon: .plusIcon, label: "Increase") {}
            HAControlButton(icon: .minusIcon, label: "Decrease") {}
        }
        HAControlButtonGroup(vertical: true) {
            HAControlButton(icon: .plusIcon, label: "Increase") {}
            HAControlButton(icon: .minusIcon, label: "Decrease") {}
        }
        .frame(height: 100)
    }
    .padding()
}

extension HAControlButtonGroup: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-button-group" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
