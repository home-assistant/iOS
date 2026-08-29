#if !os(watchOS)
import SwiftUI

/// A scrolling row of tabs with the active one underlined. The SwiftUI counterpart of the frontend's
/// `ha-tab-group` and `ha-tab`.
///
/// This is the config panel's tab bar, not the app's main navigation — for that, `TabView` is the
/// platform's answer and this would be the wrong shape.
public struct HATabGroup: View {
    private let tabs: [HATabItem]
    private let narrow: Bool
    @Binding private var selection: String?

    /// - Parameter narrow: Stacks each tab's icon over its name instead of setting them side by
    ///   side, for a bar too tight to lay them out in a row.
    public init(tabs: [HATabItem], selection: Binding<String?>, narrow: Bool = false) {
        self.tabs = tabs
        _selection = selection
        self.narrow = narrow
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .zero) {
                ForEach(tabs) { tab in
                    let isActive = selection == tab.id
                    Button {
                        selection = tab.id
                    } label: {
                        // Icon over name when narrow, beside it otherwise — the frontend flips the
                        // flex direction on the same markup.
                        Group {
                            if narrow {
                                VStack(spacing: DesignSystem.Spaces.half) { tabContent(tab) }
                            } else {
                                HStack(spacing: DesignSystem.Spaces.one) { tabContent(tab) }
                            }
                        }
                        .foregroundStyle(isActive ? Color.haPrimary : Color(uiColor: .label))
                        .padding(.horizontal, DesignSystem.Spaces.four)
                        .frame(height: 48)
                        .overlay(alignment: .bottom) {
                            if isActive {
                                Rectangle()
                                    .fill(Color.haPrimary)
                                    .frame(height: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: HATabItem) -> some View {
        if let icon = tab.icon {
            MaterialDesignIconsImage(icon: icon, size: 20)
        }
        Text(tab.name)
            .font(DesignSystem.Font.body)
            .lineLimit(1)
    }
}

private let sampleTabs = [
    HATabItem(id: "general", name: "General", icon: .cogIcon),
    HATabItem(id: "areas", name: "Areas", icon: .sofaIcon),
    HATabItem(id: "devices", name: "Devices", icon: .devicesIcon),
]

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HATabGroup(tabs: sampleTabs, selection: .constant("areas"))
        HATabGroup(tabs: sampleTabs, selection: .constant("areas"), narrow: true)
    }
    .padding()
}

extension HATabGroup: FrontendComponent {
    public static var frontendComponentName: String { "ha-tab-group" }
}

#endif
