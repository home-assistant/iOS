import Shared
import SwiftUI

struct MTLSBetaLabel: View {
    @State private var showExplanation = false
    var body: some View {
        BetaLabel(info: L10n.Mtls.Beta.info)
    }
}

#Preview {
    NavigationView {
        List {
            MTLSBetaLabel()
        }
    }
}
