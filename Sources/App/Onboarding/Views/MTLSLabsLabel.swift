import Shared
import SwiftUI

struct MTLSLabsLabel: View {
    var body: some View {
        LabsLabel(info: L10n.Mtls.Beta.info)
    }
}

#Preview {
    NavigationView {
        List {
            MTLSLabsLabel()
        }
    }
}
