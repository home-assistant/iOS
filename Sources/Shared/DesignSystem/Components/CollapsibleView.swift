import SwiftUI

public struct CollapsibleView<CollapsedContent: View, ExpandedContent: View>: View {
    @State private var expanded = false
    @ViewBuilder public let collapsedContent: () -> CollapsedContent
    @ViewBuilder public let expandedContent: () -> ExpandedContent

    public init(
        @ViewBuilder collapsedContent: @escaping () -> CollapsedContent,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.collapsedContent = collapsedContent
        self.expandedContent = expandedContent
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                collapsedContent()
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .tint(.accentColor)
            }
            .frame(maxWidth: .infinity)
            .animation(nil, value: expanded)
            .onTapGesture {
                withAnimation(.easeInOut) {
                    expanded.toggle()
                }
            }
            .accessibilityHint(
                expanded ? L10n.Component.CollapsibleView.collapse : L10n.Component.CollapsibleView
                    .expand
            )
            .accessibilityLabel(
                expanded ? L10n.Component.CollapsibleView.collapse : L10n.Component.CollapsibleView
                    .expand
            )
            VStack(alignment: .leading) {
                if expanded {
                    expandedContent()
                }
            }
        }
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
