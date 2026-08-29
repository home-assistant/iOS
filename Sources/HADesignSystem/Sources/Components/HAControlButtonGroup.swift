#if !os(watchOS)
import SwiftUI

/// Lays out control buttons in a row or column, each taking an equal share. The SwiftUI counterpart
/// of the frontend's `ha-control-button-group`.
public struct HAControlButtonGroup<Content: View>: View {
    private let vertical: Bool
    private let content: Content

    public init(vertical: Bool = false, @ViewBuilder content: () -> Content) {
        self.vertical = vertical
        self.content = content()
    }

    /// `--control-button-group-thickness`, the same 40pt a control button is.
    private static var thickness: CGFloat { 40 }

    private var layout: AnyLayout {
        vertical
            ? AnyLayout(VStackLayout(spacing: DesignSystem.Spaces.oneAndHalf))
            : AnyLayout(HStackLayout(spacing: DesignSystem.Spaces.oneAndHalf))
    }

    public var body: some View {
        layout {
            content
        }
        .frame(
            width: vertical ? Self.thickness : nil,
            height: vertical ? nil : Self.thickness
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
}

#endif
