@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// The Mac title bar buttons: which ones are laid out, which only appear with several servers, and
/// that every button runs the action it stands for.
@Suite(.sharedState)
@MainActor
struct StatusBarButtonsConfiguratorTests {
    private final class Recorder {
        var calls: [String] = []
        var openedServers: [String] = []
    }

    private func configuration(serverCount: Int, recorder: Recorder) -> StatusBarButtonsConfigurator.Configuration {
        let servers = (0 ..< serverCount).map { index in
            Server.fake(identifier: .init(rawValue: "server-\(index)")) { $0.remoteName = "Server \(index)" }
        }
        return .init(
            server: servers.first ?? .fake(),
            servers: servers,
            actions: .init(
                refresh: { recorder.calls.append("refresh") },
                openServer: { recorder.openedServers.append($0.identifier.rawValue) },
                openInSafari: { recorder.calls.append("safari") },
                goBack: { recorder.calls.append("back") },
                goForward: { recorder.calls.append("forward") },
                copy: { recorder.calls.append("copy") },
                paste: { recorder.calls.append("paste") }
            )
        )
    }

    private func buttons(in view: UIView) -> [UIButton] {
        view.subviews.flatMap { subview -> [UIButton] in
            ((subview as? UIButton).map { [$0] } ?? []) + buttons(in: subview)
        }
    }

    private func withStylingMode(
        _ mode: StatusBarButtonsConfigurator.StylingMode,
        _ body: () throws -> Void
    ) rethrows {
        let previous = StatusBarButtonsConfigurator.debugStylingMode
        StatusBarButtonsConfigurator.debugStylingMode = mode
        defer { StatusBarButtonsConfigurator.debugStylingMode = previous }
        try body()
    }

    @Test(arguments: [
        StatusBarButtonsConfigurator.StylingMode.automatic,
        .forceMacOS26,
        .forceLegacy,
    ])
    func everyButtonRunsItsAction(mode: StatusBarButtonsConfigurator.StylingMode) throws {
        try withStylingMode(mode) {
            let recorder = Recorder()
            let statusBar = UIView(frame: CGRect(x: 0, y: 0, width: 1024, height: 40))

            let stack = StatusBarButtonsConfigurator.setupButtons(
                in: statusBar,
                configuration: configuration(serverCount: 1, recorder: recorder)
            )
            statusBar.layoutIfNeeded()

            // A single server has nothing to pick between.
            #expect(stack.arrangedSubviews.isEmpty)
            let labels: [String: String] = [
                L10n.Mac.Navigation.GoBack.accessibilityLabel: "back",
                L10n.Mac.Navigation.GoForward.accessibilityLabel: "forward",
                L10n.Mac.Copy.accessibilityLabel: "copy",
                L10n.Mac.Paste.accessibilityLabel: "paste",
            ]
            let allButtons = buttons(in: statusBar)
            for (label, call) in labels {
                let button = try #require(allButtons.first { $0.accessibilityLabel == label })
                button.sendActions(for: .touchUpInside)
                #expect(recorder.calls.last == call)
            }
            for button in allButtons {
                button.sendActions(for: .touchUpInside)
            }
            #expect(recorder.calls.contains("refresh"))
            #expect(recorder.calls.contains("safari"))
        }
    }

    @Test(arguments: [StatusBarButtonsConfigurator.StylingMode.forceMacOS26, .forceLegacy])
    func severalServersAddAServerPicker(mode: StatusBarButtonsConfigurator.StylingMode) throws {
        try withStylingMode(mode) {
            let recorder = Recorder()
            let statusBar = UIView(frame: CGRect(x: 0, y: 0, width: 1024, height: 40))

            let stack = StatusBarButtonsConfigurator.setupButtons(
                in: statusBar,
                configuration: configuration(serverCount: 2, recorder: recorder)
            )
            statusBar.layoutIfNeeded()

            let picker = try #require(stack.arrangedSubviews.first)
            let pickerButton = try #require(buttons(in: picker).first)
            #expect(pickerButton.title(for: .normal) == "Server 0")
            #expect(pickerButton.showsMenuAsPrimaryAction)
            #expect(pickerButton.menu?.title == L10n.WebView.ServerSelection.title)
            #expect(pickerButton.menu?.children.map(\.title) == ["Server 0", "Server 1"])
        }
    }

    @Test func navigationButtonsAreLabelledForVoiceOver() {
        #expect(WebViewControllerButtons.backButton.accessibilityLabel != nil)
        #expect(WebViewControllerButtons.forwardButton.accessibilityLabel != nil)
        #expect(WebViewControllerButtons.copyButton.accessibilityLabel != nil)
        #expect(WebViewControllerButtons.pasteButton.accessibilityLabel != nil)
        #expect(WebViewControllerButtons.openInSafariButton.image(for: .normal) != nil)
    }
}
