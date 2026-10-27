import CoreImage.CIFilterBuiltins
import Shared
import SwiftUI
import UIKit

/// The pairing token, as a QR code to scan and as text to paste into Music Assistant.
struct SendspinPairingTokenView: View {
    let token: String

    /// Rendered once per token: the QR alphanumeric set the token is limited to keeps the code small.
    private var qrCode: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(token.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }

    var body: some View {
        List {
            Section {
                if let qrCode {
                    Image(uiImage: qrCode)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .padding()
                        .background(Color.white)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                Text(token)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = token
                } label: {
                    Label(L10n.Settings.Sendspin.PairingToken.copy, systemSymbol: .docOnDoc)
                }
            } footer: {
                Text(L10n.Settings.Sendspin.PairingToken.body)
            }
        }
        .navigationTitle(L10n.Settings.Sendspin.PairingToken.title)
    }
}

#Preview {
    NavigationView {
        SendspinPairingTokenView(
            token: "SP:0AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQTCQKRMFYYDENBWHA5DYP6BYPC4PSOLZXH5DU6V97M5XXO74HR6LZ7J5PW674PT6X37T6757Y"
        )
    }
}
