import SFSafeSymbols
import Shared
import SwiftUI
import UIKit
#if targetEnvironment(macCatalyst)
import AppKit
#endif

struct MacWebViewTitleBar: UIViewControllerRepresentable {
    let server: Server
    weak var webViewController: WebViewController?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        MacWebViewTitleBarViewController { [weak coordinator = context.coordinator] viewController in
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

private final class MacWebViewTitleBarViewController: UIViewController {
    private let updateToolbar: (MacWebViewTitleBarViewController) -> Void

    init(updateToolbar: @escaping (MacWebViewTitleBarViewController) -> Void) {
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
extension MacWebViewTitleBar {
    @MainActor
    final class Coordinator: NSObject, NSToolbarDelegate {
        private enum Constants {
            static let toolbarIdentifier = NSToolbar.Identifier("io.home-assistant.webview.toolbar")
            static let highVisibilityPriority = NSToolbarItem.VisibilityPriority.high
            static let imageCanvasSize = CGSize(width: 18, height: 18)
            static let symbolPointSize: CGFloat = 13
            static let serverPickerFontSize: CGFloat = 13
            static let serverPickerHorizontalPadding: CGFloat = 8
        }

        private weak var webViewController: WebViewController?
        private weak var titlebar: UITitlebar?
        private weak var serverPickerItem: NSMenuToolbarItem?
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
                toolbar.allowsUserCustomization = true
                toolbar.autosavesConfiguration = true

                titlebar.titleVisibility = .hidden
                if #available(macCatalyst 14.0, *) {
                    titlebar.toolbarStyle = .unifiedCompact
                    titlebar.separatorStyle = .none
                }
                titlebar.toolbar = toolbar
                self.toolbar = toolbar
            }

            updateEnabledItems()
            updateServerPicker()
        }

        func removeToolbar() {
            guard titlebar?.toolbar === toolbar else { return }
            titlebar?.toolbar = nil
            toolbar = nil
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            defaultItemIdentifiers
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            allowedItemIdentifiers
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
                    symbol: .safari,
                    action: #selector(openServerInSafari)
                )
            case .homeAssistantServerPicker:
                serverPickerToolbarItem(identifier: itemIdentifier, willBeInserted: flag)
            default:
                nil
            }
        }

        private func updateEnabledItems() {
            toolbar?.items.forEach { item in
                guard item.itemIdentifier != .homeAssistantServerPicker else {
                    item.isEnabled = true
                    return
                }
                item.isEnabled = webViewController != nil
            }
        }

        private var defaultItemIdentifiers: [NSToolbarItem.Identifier] {
            var identifiers: [NSToolbarItem.Identifier] = [
                .homeAssistantBack,
                .homeAssistantForward,
                .homeAssistantRefresh,
                .flexibleSpace,
                .homeAssistantCopy,
                .homeAssistantPaste,
                .homeAssistantOpenInSafari,
            ]
            if Current.servers.all.count > 1 {
                identifiers.append(.homeAssistantServerPicker)
            }
            return identifiers
        }

        private var allowedItemIdentifiers: [NSToolbarItem.Identifier] {
            var identifiers: [NSToolbarItem.Identifier] = [
                .homeAssistantBack,
                .homeAssistantForward,
                .homeAssistantRefresh,
                .homeAssistantCopy,
                .homeAssistantPaste,
                .homeAssistantOpenInSafari,
            ]
            if Current.servers.all.count > 1 {
                identifiers.append(.homeAssistantServerPicker)
            }
            identifiers.append(contentsOf: [.space, .flexibleSpace])
            return identifiers
        }

        private func serverPickerToolbarItem(
            identifier: NSToolbarItem.Identifier,
            willBeInserted: Bool
        ) -> NSMenuToolbarItem {
            let item = NSMenuToolbarItem(itemIdentifier: identifier)
            item.showsIndicator = true
            item.visibilityPriority = Constants.highVisibilityPriority

            guard willBeInserted else {
                let paletteLabel = L10n.ServersSelection.title
                item.label = paletteLabel
                item.paletteLabel = paletteLabel
                item.toolTip = paletteLabel
                item.image = toolbarImage(symbol: .serverRack, accessibilityLabel: paletteLabel)
                return item
            }

            serverPickerItem = item
            updateServerPicker()
            return item
        }

        private func updateServerPicker() {
            guard let serverPickerItem else { return }
            let title = server?.info.name ?? L10n.WebView.ServerSelection.title
            serverPickerItem.label = title
            serverPickerItem.paletteLabel = L10n.ServersSelection.title
            serverPickerItem.toolTip = title
            serverPickerItem.image = serverPickerTitleImage(title: title)
            serverPickerItem.itemMenu = serverPickerMenu()
        }

        private func serverPickerTitleImage(title: String) -> UIImage {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: Constants.serverPickerFontSize, weight: .regular),
                .foregroundColor: UIColor.label,
            ]
            let attributedTitle = NSAttributedString(string: title, attributes: attributes)
            let textSize = attributedTitle.size()
            let canvasSize = CGSize(
                width: ceil(textSize.width) + Constants.serverPickerHorizontalPadding * 2,
                height: ceil(textSize.height)
            )

            return UIGraphicsImageRenderer(size: canvasSize).image { _ in
                attributedTitle.draw(at: CGPoint(x: Constants.serverPickerHorizontalPadding, y: 0))
            }
            .withRenderingMode(.alwaysTemplate)
        }

        private func serverPickerMenu() -> UIMenu {
            let selectedIdentifier = server?.identifier
            let actions = Current.servers.all.map { server in
                UIAction(
                    title: server.info.name,
                    state: server.identifier == selectedIdentifier ? .on : .off
                ) { _ in
                    Current.sceneManager.appCoordinator.done { coordinator in
                        coordinator.open(server: server)
                    }
                }
            }
            return UIMenu(title: L10n.WebView.ServerSelection.title, children: actions)
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
    static let homeAssistantServerPicker = NSToolbarItem.Identifier("io.home-assistant.webview.server-picker")
}
#else
extension MacWebViewTitleBar {
    final class Coordinator: NSObject {
        func configure(
            windowScene: UIWindowScene?,
            server: Server,
            webViewController: WebViewController?
        ) {}

        func removeToolbar() {}
    }
}
#endif
