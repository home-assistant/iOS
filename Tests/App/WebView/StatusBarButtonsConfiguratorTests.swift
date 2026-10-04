@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// The macOS title bar buttons laid into the web view's status bar: which ones exist, which action each
/// one runs, and when the server picker is shown.
@MainActor
final class StatusBarButtonsConfiguratorTests: XCTestCase {
    private var calls: [String] = []
    #if DEBUG
    private var previousStylingMode: StatusBarButtonsConfigurator.StylingMode = .automatic
    #endif

    override func setUp() async throws {
        calls = []
        #if DEBUG
        previousStylingMode = StatusBarButtonsConfigurator.debugStylingMode
        #endif
    }

    override func tearDown() async throws {
        #if DEBUG
        StatusBarButtonsConfigurator.debugStylingMode = previousStylingMode
        #endif
        calls = []
    }

    // MARK: - Helpers

    private func makeConfiguration(servers: [Server]) -> StatusBarButtonsConfigurator.Configuration {
        StatusBarButtonsConfigurator.Configuration(
            server: servers[0],
            servers: servers,
            actions: .init(
                refresh: { [weak self] in self?.calls.append("refresh") },
                openServer: { [weak self] server in self?.calls.append("open \(server.info.name)") },
                openInSafari: { [weak self] in self?.calls.append("safari") },
                goBack: { [weak self] in self?.calls.append("back") },
                goForward: { [weak self] in self?.calls.append("forward") },
                copy: { [weak self] in self?.calls.append("copy") },
                paste: { [weak self] in self?.calls.append("paste") }
            )
        )
    }

    private func makeStatusBar() -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 30))
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }

    private func buttons(in view: UIView) -> [UIButton] {
        descendants(of: view).compactMap { $0 as? UIButton }
    }

    private func button(labelled label: String, in view: UIView) -> UIButton? {
        buttons(in: view).first { $0.accessibilityLabel == label }
    }

    // MARK: - Tests

    func testSingleServerHasNoServerPicker() {
        let statusBar = makeStatusBar()

        let stack = StatusBarButtonsConfigurator.setupButtons(
            in: statusBar,
            configuration: makeConfiguration(servers: [Server.fake()])
        )

        XCTAssertTrue(stack.arrangedSubviews.isEmpty)
        XCTAssertTrue(stack.superview === statusBar)
        // The picker stack, the navigation buttons and the copy/paste buttons.
        XCTAssertEqual(statusBar.subviews.count, 3)
    }

    func testSeveralServersShowAPickerListingEveryServer() throws {
        let first = Server.fake(update: { $0.remoteName = "Home" })
        let second = Server.fake(update: { $0.remoteName = "Cabin" })
        let statusBar = makeStatusBar()

        let stack = StatusBarButtonsConfigurator.setupButtons(
            in: statusBar,
            configuration: makeConfiguration(servers: [first, second])
        )

        let picker = try XCTUnwrap(stack.arrangedSubviews.first)
        XCTAssertEqual(stack.arrangedSubviews.count, 1)
        let pickerButton = try XCTUnwrap(buttons(in: picker).first)
        XCTAssertTrue(pickerButton.showsMenuAsPrimaryAction)
        let menu = try XCTUnwrap(pickerButton.menu)
        XCTAssertEqual(menu.title, L10n.WebView.ServerSelection.title)
        XCTAssertEqual(menu.children.map(\.title), ["Home", "Cabin"])
    }

    func testButtonsRunTheirActions() throws {
        let statusBar = makeStatusBar()
        _ = StatusBarButtonsConfigurator.setupButtons(
            in: statusBar,
            configuration: makeConfiguration(servers: [Server.fake()])
        )

        try XCTUnwrap(button(labelled: L10n.Mac.Navigation.GoBack.accessibilityLabel, in: statusBar))
            .sendActions(for: .touchUpInside)
        try XCTUnwrap(button(labelled: L10n.Mac.Navigation.GoForward.accessibilityLabel, in: statusBar))
            .sendActions(for: .touchUpInside)
        try XCTUnwrap(button(labelled: L10n.Mac.Copy.accessibilityLabel, in: statusBar))
            .sendActions(for: .touchUpInside)
        try XCTUnwrap(button(labelled: L10n.Mac.Paste.accessibilityLabel, in: statusBar))
            .sendActions(for: .touchUpInside)

        XCTAssertEqual(calls, ["back", "forward", "copy", "paste"])
    }

    func testSafariAndReloadButtonsRunTheirActions() throws {
        let statusBar = makeStatusBar()
        _ = StatusBarButtonsConfigurator.setupButtons(
            in: statusBar,
            configuration: makeConfiguration(servers: [Server.fake()])
        )

        // The navigation stack is the second view added: open in Safari, back/forward, then reload.
        let navigationStack = try XCTUnwrap(statusBar.subviews[1] as? UIStackView)
        XCTAssertEqual(navigationStack.arrangedSubviews.count, 3)
        let safari = try XCTUnwrap(buttons(in: navigationStack.arrangedSubviews[0]).first)
        let reload = try XCTUnwrap(buttons(in: navigationStack.arrangedSubviews[2]).first)

        safari.sendActions(for: .touchUpInside)
        reload.sendActions(for: .touchUpInside)

        XCTAssertEqual(calls, ["safari", "refresh"])
    }

    #if DEBUG
    func testGlassStylingAddsABlurBehindEachButton() {
        StatusBarButtonsConfigurator.debugStylingMode = .forceMacOS26
        let statusBar = makeStatusBar()

        _ = StatusBarButtonsConfigurator.setupButtons(
            in: statusBar,
            configuration: makeConfiguration(servers: [Server.fake(), Server.fake()])
        )
        statusBar.layoutIfNeeded()

        let blurs = descendants(of: statusBar).compactMap { $0 as? UIVisualEffectView }
        // Open in Safari, the back/forward pill, reload, copy, paste and the server picker.
        XCTAssertEqual(blurs.count, 6)
    }

    func testLegacyStylingUsesSolidContainers() {
        StatusBarButtonsConfigurator.debugStylingMode = .forceLegacy
        let statusBar = makeStatusBar()

        _ = StatusBarButtonsConfigurator.setupButtons(
            in: statusBar,
            configuration: makeConfiguration(servers: [Server.fake(), Server.fake()])
        )
        statusBar.layoutIfNeeded()

        XCTAssertTrue(descendants(of: statusBar).compactMap { $0 as? UIVisualEffectView }.isEmpty)
        let navigationStack = statusBar.subviews.compactMap { $0 as? UIStackView }[1]
        XCTAssertEqual(navigationStack.arrangedSubviews.first?.backgroundColor, .systemGray5)
    }
    #endif
}
