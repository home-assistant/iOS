import Shared
import SwiftUI

struct RecoveredServerClientCertificateImportView: View {
    let request: OnboardingClientCertificateRequest
    let asSheet: Bool

    var body: some View {
        if asSheet {
            NavigationView { content }
                .navigationViewStyle(.stack)
                .presentationDetents([.medium])
        } else {
            content.navigationBarBackButtonHidden(true)
        }
    }

    private var content: some View {
        ClientCertificateOnboardingView(onImport: { request.complete(with: $0) }, onCancel: { request.cancel() })
    }
}

#Preview {
    RecoveredServerClientCertificateImportView(
        request: OnboardingClientCertificateRequest(onImport: { _ in }, onCancel: {}),
        asSheet: true
    )
}
