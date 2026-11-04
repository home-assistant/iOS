import Shared
import SwiftUI

/// Presents `OnboardingServerIdentityView` as a sheet in its own stack so "Why am I seeing this?"
/// can push the explanation. The page's buttons are the way out, and a dismissal without a choice
/// still cancels the request.
struct OnboardingServerIdentitySheet: View {
    let request: OnboardingServerIdentityRequest

    var body: some View {
        NavigationStack {
            OnboardingServerIdentityView(request: request)
        }
        .interactiveDismissDisabled()
        .onDisappear(perform: request.cancel)
    }
}

#Preview {
    OnboardingServerIdentitySheet(request: OnboardingServerIdentityRequest(
        newServer: ServerIdentityConflictingServer(name: "Chalet", address: "http://chalet.example.com:8123"),
        existingServer: ServerIdentityConflictingServer(name: "Home", address: "http://homeassistant.local:8123"),
        onDecision: { _ in },
        onCancel: {}
    ))
}
