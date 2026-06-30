import SFSafeSymbols
import Shared
import SwiftUI
import UIKit
#if targetEnvironment(macCatalyst)
import AppKit
#endif

struct MacWebViewToolbar: UIViewControllerRepresentable {
    let server: Server
    weak var webViewController: WebViewController?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        MacWebViewToolbarViewController { [weak coordinator = context.coordinator] viewController in
            coordinator?.configure(
                windowScene: viewController.view.window?.windowScene,
                server: server,
                webViewController: webViewController
            )
        }
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        context.coordinator.configure(
            windowScene: viewController.view.window?.windowScene,
            server: server,
            webViewController: webViewController
        )
    }

    static func dismantleUIViewController(_ viewController: UIViewController, coordinator: Coordinator) {
        coordinator.removeToolbar()
    }
}

private final class MacWebViewToolbarViewController: UIViewController {
    private let updateToolbar: (MacWebViewToolbarViewController) -> Void

    init(updateToolbar: @escaping (MacWebViewToolbarViewController) -> Void) {
        self.updateToolbar = updateToolbar
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateToolbar(self)
    }
}

#if targetEnvironment(macCatalyst)
extension MacWebViewToolbar {
    @MainActor
    final class Coordinator: NSObject, NSToolbarDelegate {
        private enum Constants {
            static let toolbarIdentifier = NSToolbar.Identifier("io.home-assistant.webview.toolbar")
            static let highVisibilityPriority = NSToolbarItem.VisibilityPriority.high
            static let imageCanvasSize = CGSize(width: 18, height: 18)
            static let symbolPointSize: CGFloat = 13
        }

        private weak var webViewController: WebViewController?
        private weak var titlebar: UITitlebar?
        private var toolbar: NSToolbar?
        private var server: Server?

        func configure(
            windowScene: UIWindowScene?,
            server: Server,
            webViewController: WebViewController?
        ) {
            self.server = server
            self.webViewController = webViewController

            guard let titlebar = windowScene?.titlebar else { return }
            self.titlebar = titlebar

            if toolbar == nil || titlebar.toolbar !== toolbar {
                let toolbar = NSToolbar(identifier: Constants.toolbarIdentifier)
                toolbar.delegate = self
                toolbar.displayMode = .iconOnly
                toolbar.allowsUserCustomization = false
                toolbar.autosavesConfiguration = false

                titlebar.titleVisibility = .hidden
                if #available(macCatalyst 14.0, *) {
                    titlebar.toolbarStyle = .unifiedCompact
                    titlebar.separatorStyle = .none
                }
                titlebar.toolbar = toolbar
                self.toolbar = toolbar
            }

            updateEnabledItems()
        }

        func removeToolbar() {
            guard titlebar?.toolbar === toolbar else { return }
            titlebar?.toolbar = nil
            toolbar = nil
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            toolbarItemIdentifiers
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            toolbarItemIdentifiers
        }

        func toolbar(
            _ toolbar: NSToolbar,
            itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
            willBeInsertedIntoToolbar flag: Bool
        ) -> NSToolbarItem? {
            switch itemIdentifier {
            case .homeAssistantBack:
                toolbarItem(
                    identifier: itemIdentifier,
                    label: L10n.Mac.Navigation.GoBack.accessibilityLabel,
                    symbol: .chevronLeft,
                    action: #selector(goBack)
                )
            case .homeAssistantForward:
                toolbarItem(
                    identifier: itemIdentifier,
                    label: L10n.Mac.Navigation.GoForward.accessibilityLabel,
                    symbol: .chevronRight,
                    action: #selector(goForward)
                )
            case .homeAssistantRefresh:
                toolbarItem(
                    identifier: itemIdentifier,
                    label: L10n.Watch.Settings.refresh,
                    symbol: .arrowClockwise,
                    action: #selector(refresh)
                )
            case .homeAssistantCopy:
                toolbarItem(
                    identifier: itemIdentifier,
                    label: L10n.Mac.Copy.accessibilityLabel,
                    symbol: .docOnDoc,
                    action: #selector(copyCurrentSelectedContent)
                )
            case .homeAssistantPaste:
                toolbarItem(
                    identifier: itemIdentifier,
                    label: L10n.Mac.Paste.accessibilityLabel,
                    symbol: .docOnClipboard,
                    action: #selector(pasteContent)
                )
            case .homeAssistantOpenInSafari:
                toolbarItem(
                    identifier: itemIdentifier,
                    label: L10n.Mac.OpenInSafari.accessibilityLabel,
                    symbol: .safariFill,
                    action: #selector(openServerInSafari)
                )
            default:
                nil
            }
        }

        private func updateEnabledItems() {
            toolbar?.items.forEach { item in
                item.isEnabled = webViewController != nil
            }
        }

        private var toolbarItemIdentifiers: [NSToolbarItem.Identifier] {
            [
                .homeAssistantBack,
                .homeAssistantForward,
                .homeAssistantRefresh,
                .flexibleSpace,
                .homeAssistantCopy,
                .homeAssistantPaste,
                .homeAssistantOpenInSafari,
            ]
        }

        private func toolbarItem(
            identifier: NSToolbarItem.Identifier,
            label: String,
            symbol: SFSymbol,
            action: Selector
        ) -> NSToolbarItem {
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.label = label
            item.paletteLabel = label
            item.toolTip = label
            item.image = toolbarImage(symbol: symbol, accessibilityLabel: label)
            item.target = self
            item.action = action
            item.visibilityPriority = Constants.highVisibilityPriority
            return item
        }

        private func toolbarImage(symbol: SFSymbol, accessibilityLabel: String) -> UIImage {
            let configuration = UIImage.SymbolConfiguration(
                pointSize: Constants.symbolPointSize,
                weight: .regular
            )
            let symbolImage = UIImage(systemSymbol: symbol)
                .applyingSymbolConfiguration(configuration) ?? UIImage(systemSymbol: symbol)

            return UIGraphicsImageRenderer(size: Constants.imageCanvasSize).image { _ in
                symbolImage.draw(in: CGRect(
                    origin: CGPoint(
                        x: (Constants.imageCanvasSize.width - symbolImage.size.width) / 2,
                        y: (Constants.imageCanvasSize.height - symbolImage.size.height) / 2
                    ),
                    size: symbolImage.size
                ))
            }
            .withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        }

        @objc private func goBack() {
            webViewController?.goBack()
        }

        @objc private func goForward() {
            webViewController?.goForward()
        }

        @objc private func refresh() {
            webViewController?.refresh()
        }

        @objc private func copyCurrentSelectedContent() {
            webViewController?.copyCurrentSelectedContent()
        }

        @objc private func pasteContent() {
            webViewController?.pasteContent()
        }

        @objc private func openServerInSafari() {
            webViewController?.openServerInSafari()
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let homeAssistantBack = NSToolbarItem.Identifier("io.home-assistant.webview.back")
    static let homeAssistantForward = NSToolbarItem.Identifier("io.home-assistant.webview.forward")
    static let homeAssistantRefresh = NSToolbarItem.Identifier("io.home-assistant.webview.refresh")
    static let homeAssistantCopy = NSToolbarItem.Identifier("io.home-assistant.webview.copy")
    static let homeAssistantPaste = NSToolbarItem.Identifier("io.home-assistant.webview.paste")
    static let homeAssistantOpenInSafari = NSToolbarItem.Identifier("io.home-assistant.webview.open-in-safari")
}
#else
extension MacWebViewToolbar {
    final class Coordinator: NSObject {}
}
#endif
