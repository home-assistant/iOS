import SFSafeSymbols
import Shared
import SwiftUI

/// Gives the web frontend a navigation bar whose leading item stands in for the back arrow the
/// frontend stopped drawing once it saw `hasNativeBackButton`.
///
/// The bar is only there while the frontend reports a back action, so pages without one keep the
/// full height for their own content. Devices that do not take the back button over are left with
/// the frontend exactly as it was.
@available(iOS 26, *)
struct NativeBackButtonToolbar: ViewModifier {
    @ObservedObject var state: NativeBackButtonState = .shared

    let webViewController: WebViewController?

    @ViewBuilder
    func body(content: Content) -> some View {
        if state.isSupported {
            NavigationStack {
                content
                    .toolbar {
                        if state.isVisible {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    webViewController?.webViewExternalMessageHandler
                                        .sendBackButtonPressed()
                                } label: {
                                    Label(L10n.backLabel, systemSymbol: .chevronBackward)
                                }
                            }
                        }
                    }
                    .toolbarVisibility(state.isVisible ? .visible : .hidden, for: .navigationBar)
            }
        } else {
            content
        }
    }
}

@available(iOS 26, *)
#Preview {
    Color.haPrimary
        .modifier(NativeBackButtonToolbar(webViewController: nil))
}
