@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import XCTest

@MainActor
final class ThreadCredentialSharingModeViewSnapshotTests: XCTestCase {
    private static let credentials: [ThreadCredential] = [
        ThreadCredential(
            networkName: "Home",
            networkKey: "00112233445566778899aabbccddeeff",
            extendedPANID: "deadbeef00112233",
            borderAgentID: "0011223344556677",
            macExtendedAddress: "0011223344556677",
            activeOperationalDataSet: "0e080000000000010000",
            pskc: "00112233445566778899aabbccddeeff",
            channel: 25,
            panID: "1234"
        ),
        ThreadCredential(
            networkName: "Garage",
            networkKey: "ffeeddccbbaa99887766554433221100",
            extendedPANID: "0123456789abcdef",
            borderAgentID: "7766554433221100",
            macExtendedAddress: "7766554433221100",
            activeOperationalDataSet: "0e080000000000010000",
            pskc: "ffeeddccbbaa99887766554433221100",
            channel: 15,
            panID: "abcd"
        ),
    ]

    private func makeView(
        credentials: [ThreadCredential]?,
        extendedPANID: String = "",
        state: ThreadCredentialSharingModeViewModel.State = .idle
    ) -> some View {
        let threadClientService = SimulatorThreadClientService()
        threadClientService.suspendRetrieveAllCredentials = true
        return NavigationView {
            ThreadCredentialSharingModeView(viewModel: ThreadCredentialSharingModeViewModel(
                threadClientService: threadClientService,
                credentials: credentials,
                extendedPANID: extendedPANID,
                state: state
            ))
        }
    }

    func testThreadSharingModeLoadingKeychain() {
        assertLightDarkSnapshots(
            of: makeView(credentials: nil),
            drawHierarchyInKeyWindow: true
        )
    }

    func testThreadSharingModeWithNetworks() {
        assertLightDarkSnapshots(
            of: makeView(credentials: Self.credentials),
            drawHierarchyInKeyWindow: true
        )
    }

    func testThreadSharingModeEmptyKeychain() {
        assertLightDarkSnapshots(
            of: makeView(credentials: []),
            drawHierarchyInKeyWindow: true
        )
    }

    func testThreadSharingModeRequestInFlight() {
        assertLightDarkSnapshots(
            of: makeView(credentials: Self.credentials, extendedPANID: "deadbeef00112233", state: .loading),
            drawHierarchyInKeyWindow: true
        )
    }

    func testThreadSharingModeSuccess() {
        assertLightDarkSnapshots(
            of: makeView(credentials: Self.credentials, extendedPANID: "deadbeef00112233", state: .success),
            drawHierarchyInKeyWindow: true
        )
    }

    func testThreadSharingModeFailure() {
        assertLightDarkSnapshots(
            of: makeView(
                credentials: Self.credentials,
                extendedPANID: "deadbeef00112233",
                state: .failure("Thread credential sharing mode requires iOS 27 or later.")
            ),
            drawHierarchyInKeyWindow: true
        )
    }
}
