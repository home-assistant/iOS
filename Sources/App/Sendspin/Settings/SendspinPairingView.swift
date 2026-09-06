import Shared
import SwiftUI
import UIKit

/// Shows the pairing token an operator enters into their server. Pairing replaces an unpaired
/// session — which any device on the network could impersonate either end of — with one
/// authenticated by a long-term key the two sides then keep.
struct SendspinPairingView: View {
    @State private var isRevealed = false

    private let token = SendspinPlayerManager.shared.pairingToken

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .qrcodeIcon,
                title: L10n.Settings.Sendspin.Pairing.title,
                subtitle: L10n.Settings.Sendspin.Pairing.body
            )

            Section(footer: Text(L10n.Settings.Sendspin.Pairing.warning)) {
                if isRevealed {
                    HAQRCode(data: token.string, scale: 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DesignSystem.Spaces.one)
                    Text(token.string)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = token.string
                    } label: {
                        Text(L10n.Settings.Sendspin.Pairing.copy)
                    }
                } else {
                    Button {
                        isRevealed = true
                    } label: {
                        Text(L10n.Settings.Sendspin.Pairing.reveal)
                    }
                }
            }
        }
        .listTopContentMargin()
    }
}

#Preview {
    NavigationView {
        SendspinPairingView()
    }
}
