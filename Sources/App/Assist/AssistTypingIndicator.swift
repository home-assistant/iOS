import SFSafeSymbols
import SwiftUI

struct AssistTypingIndicator: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            icon
                .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing, options: .repeat(.continuous))
        } else if #available(iOS 17.0, *) {
            icon
                .symbolEffect(.variableColor)
        } else {
            icon
        }
    }

    private var icon: some View {
        Image(systemSymbol: .ellipsis)
            .font(.title.bold())
    }
}

#Preview {
    AssistTypingIndicator()
        .padding()
        .background(.gray.opacity(0.5))
        .cornerRadius(12)
}
