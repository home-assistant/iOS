import Shared
import SwiftUI

#Preview("Disconnected") {
    WebViewEmptyStateView(
        style: .disconnected,
        server: ServerFixture.standard
    )
}

#Preview("Disconnected With Error Details") {
    WebViewEmptyStateView(
        style: .disconnected,
        server: ServerFixture.standard,
        showsErrorDetailsButton: true,
        errorDetailsAction: {}
    )
}

#Preview("Unauthenticated") {
    WebViewEmptyStateView(
        style: .unauthenticated,
        server: ServerFixture.standard,
        availableReauthURLTypes: [.external],
        reauthAction: { _ in }
    )
}

#Preview("Unauthenticated Multiple URLs") {
    WebViewEmptyStateView(
        style: .unauthenticated,
        server: ServerFixture.standard,
        availableReauthURLTypes: [.remoteUI, .external, .internal],
        reauthAction: { _ in }
    )
}

#Preview("Recovered Server Reauthentication") {
    WebViewEmptyStateView(
        style: .recoveredServerNeedingReauthentication,
        server: ServerFixture.standard,
        availableReauthURLTypes: [.remoteUI, .external],
        recoveredServerReauthAction: { _, completion in
            completion(.success(()))
        }
    )
}

#Preview("Recovered Server Reauthentication Dark") {
    WebViewEmptyStateView(
        style: .recoveredServerNeedingReauthentication,
        server: ServerFixture.standard,
        availableReauthURLTypes: [.remoteUI, .external],
        recoveredServerReauthAction: { _, completion in
            completion(.failure(NSError(
                domain: "Preview",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Reauthentication failed."]
            )))
        }
    )
    .preferredColorScheme(.dark)
}
