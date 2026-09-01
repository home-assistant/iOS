import Shared
import SwiftUI

/// Title, body and complementary hint of the connection/re-authentication empty state, shared by
/// `HomeAssistantStandByView` and `WebViewEmptyStateView`.
struct WebViewEmptyStateMessage: View {
    let style: WebViewEmptyStateStyle
    let server: Server
    let complementaryMessageAction: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(style.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(bodyText)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)
            if let complementaryMessage = style.complementaryMessage {
                Button(action: complementaryMessageAction) {
                    Text(complementaryMessage)
                        .font(.caption2.italic())
                        .foregroundColor(.haPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spaces.two)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bodyText: String {
        switch style {
        case .disconnected, .inFlight, .unauthenticated, .loggedOut:
            style.body
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.message(server.info.name)
        }
    }
}

#Preview("Disconnected") {
    WebViewEmptyStateMessage(
        style: .disconnected,
        server: ServerFixture.standard,
        complementaryMessageAction: {}
    )
}

#Preview("In-flight") {
    WebViewEmptyStateMessage(
        style: .inFlight,
        server: ServerFixture.standard,
        complementaryMessageAction: {}
    )
}

#Preview("Recovered Reauthentication") {
    WebViewEmptyStateMessage(
        style: .recoveredServerNeedingReauthentication,
        server: ServerFixture.standard,
        complementaryMessageAction: {}
    )
}
