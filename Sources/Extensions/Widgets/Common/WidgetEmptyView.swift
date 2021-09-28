import SwiftUI

struct WidgetEmptyView: View {
    let message: String

    init(message: String) {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            Text(verbatim: message)
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
        }
    }
}
