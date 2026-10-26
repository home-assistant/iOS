@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct RecoveredServerReauthViewRenderTests {
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func makeViewModel() -> RecoveredServerReauthViewModel {
        RecoveredServerReauthViewModel(server: Server.fake(), state: OnboardingStateObservable())
    }

    @Test func rendersTheReauthScreen() {
        let previousIsCatalyst = Current.isCatalyst
        defer { Current.isCatalyst = previousIsCatalyst }
        Current.isCatalyst = false

        render(RecoveredServerReauthView(server: Server.fake(), state: OnboardingStateObservable()))
    }

    @Test func rendersTheCertificateImportPageOnCatalyst() {
        let previousIsCatalyst = Current.isCatalyst
        defer { Current.isCatalyst = previousIsCatalyst }
        Current.isCatalyst = true
        let viewModel = makeViewModel()
        _ = viewModel.importClientCertificate()

        render(RecoveredServerReauthView(viewModel: viewModel))
        viewModel.cancelCertificateImport()
    }

    @Test func rendersTheCertificateImportAsSheetAndAsPage() {
        let request = OnboardingClientCertificateRequest(onImport: { _ in }, onCancel: {})

        render(RecoveredServerClientCertificateImportView(request: request, asSheet: true))
        render(RecoveredServerClientCertificateImportView(request: request, asSheet: false))
    }
}
