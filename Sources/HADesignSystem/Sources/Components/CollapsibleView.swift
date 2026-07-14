#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

public struct CollapsibleView<CollapsedContent: View, ExpandedContent: View>: View {
    @State private var expanded = false
    @ViewBuilder public let collapsedContent: () -> CollapsedContent
    @ViewBuilder public let expandedContent: () -> ExpandedContent

    private let startExpanded: Bool

    public init(
        startExpanded: Bool = false,
        @ViewBuilder collapsedContent: @escaping () -> CollapsedContent,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.collapsedContent = collapsedContent
        self.expandedContent = expandedContent
        self.startExpanded = startExpanded
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                collapsedContent()
                Spacer()
                Image(systemSymbol: expanded ? .chevronUp : .chevronDown)
                    .tint(.accentColor)
            }
            .frame(maxWidth: .infinity)
            .animation(nil, value: expanded)
            .onAppear {
                expanded = startExpanded
            }
            .onTapGesture {
                withAnimation(.easeInOut) {
                    expanded.toggle()
                }
            }
            .accessibilityHint(toggleAccessibilityText)
            .accessibilityLabel(toggleAccessibilityText)
            VStack(alignment: .leading) {
                if expanded {
                    expandedContent()
                }
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
#endif
