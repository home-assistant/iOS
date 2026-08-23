@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

@MainActor
final class WebViewEmptyStateHeaderTests: XCTestCase {
    private var windows: [UIWindow] = []

    override func tearDown() {
        windows.removeAll()
        super.tearDown()
    }

    func testShowsServerSelectionWhenMultipleServersExistOffCatalyst() {
        XCTAssertTrue(
            WebViewEmptyStateHeader.showsServerSelection(
                style: .disconnected,
                serverCount: 2,
                isCatalyst: false
            )
        )
        XCTAssertTrue(
            WebViewEmptyStateHeader.showsServerSelection(
                style: .unauthenticated,
                serverCount: 3,
                isCatalyst: false
            )
        )
    }

    func testHidesServerSelectionWhenOnlyOneServerExists() {
        XCTAssertFalse(
            WebViewEmptyStateHeader.showsServerSelection(
                style: .disconnected,
                serverCount: 1,
                isCatalyst: false
            )
        )
        XCTAssertFalse(
            WebViewEmptyStateHeader.showsServerSelection(
                style: .disconnected,
                serverCount: 0,
                isCatalyst: false
            )
        )
    }

    func testHidesServerSelectionOnCatalystEvenWithMultipleServers() {
        XCTAssertFalse(
            WebViewEmptyStateHeader.showsServerSelection(
                style: .disconnected,
                serverCount: 2,
                isCatalyst: true
            )
        )
    }

    func testHeaderHostsServerPickerWhenMultipleServersExist() throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let servers = FakeServerManager(initial: 2)
        Current.servers = servers
        let server = try XCTUnwrap(servers.all.first)

        let host = hostedHeader(
            server: server,
            showsServerSelection: WebViewEmptyStateHeader.showsServerSelection(
                style: .disconnected,
                serverCount: servers.all.count,
                isCatalyst: false
            )
        )

        XCTAssertTrue(host.view.ha_containsPicker(), "Expected a menu picker when more than one server exists")
    }

    func testHeaderOmitsServerPickerWhenOnlyOneServerExists() throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        let server = try XCTUnwrap(servers.all.first)

        let host = hostedHeader(
            server: server,
            showsServerSelection: WebViewEmptyStateHeader.showsServerSelection(
                style: .disconnected,
                serverCount: servers.all.count,
                isCatalyst: false
            )
        )

        XCTAssertFalse(host.view.ha_containsPicker(), "A single server should not show a server picker")
    }

    private func hostedHeader(
        server: Server,
        showsServerSelection: Bool
    ) -> UIHostingController<WebViewEmptyStateHeader> {
        let header = WebViewEmptyStateHeader(
            style: .disconnected,
            server: server,
            isLoading: false,
            showsServerSelection: showsServerSelection,
            showsErrorDetailsButton: false,
            settingsAction: {},
            serverSelectionAction: { _ in },
            dismissAction: {}
        )
        let host = UIHostingController(rootView: header)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 120))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        windows.append(window)
        return host
    }
}

private extension UIView {
    func ha_containsPicker() -> Bool {
        if self is UIPickerView { return true }
        if let button = self as? UIButton, button.menu != nil { return true }
        let typeName = String(describing: type(of: self))
        if typeName.localizedCaseInsensitiveContains("picker") { return true }
        if accessibilityLabel == L10n.ServersSelection.title { return true }
        return subviews.contains { $0.ha_containsPicker() }
    }
}
