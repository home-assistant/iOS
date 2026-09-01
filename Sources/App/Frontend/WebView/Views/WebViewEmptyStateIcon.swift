import SFSafeSymbols
import Shared
import SwiftUI

/// Icon of the connection/re-authentication empty state, shared by `HomeAssistantStandByView` and
/// `WebViewEmptyStateView`. A `nil` style is the stand-by loader, which shows the same logo.
struct WebViewEmptyStateIcon: View {
    static let logoSize = CGSize(width: 80, height: 80)
    static let reauthenticationIconSize: CGFloat = 56

    let style: WebViewEmptyStateStyle?
    var size: CGSize = WebViewEmptyStateIcon.logoSize

    var body: some View {
        if style == .recoveredServerNeedingReauthentication {
            Image(systemSymbol: .key)
                .font(.system(size: Self.reauthenticationIconSize))
                .foregroundStyle(Color.haPrimary)
        } else {
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
        }
    }
}

#Preview("Logo") {
    WebViewEmptyStateIcon(style: .disconnected)
}

#Preview("Re-authentication Key") {
    WebViewEmptyStateIcon(style: .recoveredServerNeedingReauthentication)
}
