#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// A header that reveals its content when tapped — the design system's counterpart of the frontend's
/// `ha-expansion-panel`.
public struct CollapsibleView<CollapsedContent: View, ExpandedContent: View>: View {
    @State private var expanded = false
    @ViewBuilder public let collapsedContent: () -> CollapsedContent
    @ViewBuilder public let expandedContent: () -> ExpandedContent

    private let startExpanded: Bool
    private let outlined: Bool
    private let leftChevron: Bool
    private let noCollapse: Bool

    /// - Parameters:
    ///   - outlined: Draws a border around the whole panel, `ha-expansion-panel`'s `outlined`.
    ///   - leftChevron: Puts the chevron ahead of the header instead of after it.
    ///   - noCollapse: Shows the content permanently, with no chevron and no tap target. The
    ///     frontend uses this for a panel whose contents should always be visible in some contexts.
    public init(
        startExpanded: Bool = false,
        outlined: Bool = false,
        leftChevron: Bool = false,
        noCollapse: Bool = false,
        @ViewBuilder collapsedContent: @escaping () -> CollapsedContent,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.collapsedContent = collapsedContent
        self.expandedContent = expandedContent
        self.startExpanded = startExpanded
        self.outlined = outlined
        self.leftChevron = leftChevron
        self.noCollapse = noCollapse
    }

    /// `noCollapse` pins the panel open, so the header stops being a control.
    private var isShowingContent: Bool {
        noCollapse || expanded
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if leftChevron, !noCollapse {
                    Image(systemSymbol: expanded ? .chevronUp : .chevronDown)
                        .tint(.accentColor)
                }
                collapsedContent()
                Spacer()
                if !leftChevron, !noCollapse {
                    Image(systemSymbol: expanded ? .chevronUp : .chevronDown)
                        .tint(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(nil, value: expanded)
            .onAppear {
                expanded = startExpanded
            }
            .onTapGesture {
                guard !noCollapse else { return }
                withAnimation(.easeInOut) {
                    expanded.toggle()
                }
            }
            .accessibilityHint(toggleAccessibilityText)
            .accessibilityLabel(toggleAccessibilityText)
            VStack(alignment: .leading) {
                if isShowingContent {
                    expandedContent()
                }
            }
        }
        .modify { view in
            if outlined {
                view
                    .padding(DesignSystem.Spaces.one)
                    .overlay(
                        RoundedRectangle(cornerRadius: HACornerRadius.standard)
                            .strokeBorder(Color.haDivider, lineWidth: DesignSystem.Border.Width.default)
                    )
            } else {
                view
            }
        }
    }

    private var toggleAccessibilityText: String {
        expanded ? HADesignSystemEnvironment.current.strings.collapsibleViewCollapse
            : HADesignSystemEnvironment.current.strings.collapsibleViewExpand
    }
}

#Preview {
    List {
        CollapsibleView(collapsedContent: {
            Text("abc")
        }, expandedContent: {
            VStack {
                Text("abc")
                Text("abc")
                Text("abc")
                Text("abc")
            }
        })
        CollapsibleView(collapsedContent: {
            Text("abc")
        }, expandedContent: {
            VStack {
                Text("abc")
                Text("abc")
                Text("abc")
                Text("abc")
            }
        })
    }
}

extension CollapsibleView: FrontendComponent {
    public static var frontendComponentName: String { "ha-expansion-panel" }
}

#endif
