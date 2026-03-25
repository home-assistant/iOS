import Shared
import SwiftUI

struct MTLSBetaLabel: View {
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
