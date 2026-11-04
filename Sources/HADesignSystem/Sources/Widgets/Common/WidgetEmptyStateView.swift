#if !os(watchOS)
import SwiftUI

/// What a widget shows instead of its content when there is nothing configured to show.
public struct WidgetEmptyStateView: View {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            Text(verbatim: message)
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
        }
    }
}

#Preview {
    WidgetEmptyStateView(message: "Nothing configured yet")
        .frame(width: 160, height: 160)
}
#endif
