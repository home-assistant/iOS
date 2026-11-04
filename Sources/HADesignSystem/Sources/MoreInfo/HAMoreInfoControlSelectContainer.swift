#if !os(watchOS)
import SwiftUI

/// The row of mode pickers under a more-info dialog's main control. The SwiftUI counterpart of the
/// frontend's `ha-more-info-control-select-container`.
///
/// Centred while the pickers fit and scrolling sideways once they do not, as the frontend does on a
/// phone.
public struct HAMoreInfoControlSelectContainer<Trailing: View>: View {
    private let selects: [HAMoreInfoSelect]
    private let trailing: Trailing

    /// - Parameter trailing: Anything that sits in the row after the pickers, sized like one,
    ///   the vacuum's clean-by-area button.
    public init(selects: [HAMoreInfoSelect], @ViewBuilder trailing: () -> Trailing) {
        self.selects = selects
        self.trailing = trailing()
    }

    private static var itemMinWidth: CGFloat { 120 }
    private static var itemMaxWidth: CGFloat { 160 }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            items
                .frame(maxWidth: .infinity)
            ScrollView(.horizontal, showsIndicators: false) {
                items
                    .padding(.horizontal, DesignSystem.Spaces.three)
            }
            .padding(.horizontal, -DesignSystem.Spaces.three)
        }
    }

    private var items: some View {
        HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
            ForEach(selects) { select in
                HAControlSelectMenu(select)
                    .frame(minWidth: Self.itemMinWidth, maxWidth: Self.itemMaxWidth)
                    .fixedSize()
            }
            trailing
        }
    }
}

public extension HAMoreInfoControlSelectContainer where Trailing == EmptyView {
    init(selects: [HAMoreInfoSelect]) {
        self.init(selects: selects) { EmptyView() }
    }
}

#Preview {
    HAMoreInfoControlSelectContainer(selects: [
        HAMoreInfoSelect(
            id: "mode",
            label: "Mode",
            icon: .thermostatIcon,
            options: [.init(id: "heat", label: "Heat", icon: .fireIcon)],
            selection: .constant("heat")
        ),
        HAMoreInfoSelect(
            id: "preset",
            label: "Preset",
            icon: .tuneVariantIcon,
            options: [.init(id: "eco", label: "Eco", icon: .leafIcon)],
            selection: .constant("eco")
        ),
    ])
    .padding()
}

extension HAMoreInfoControlSelectContainer: FrontendComponent {
    public static var frontendComponentName: String { "ha-more-info-control-select-container" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
