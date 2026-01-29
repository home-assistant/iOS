import Foundation
import PromiseKit
@preconcurrency import Shared

/// Handles the "Add To" functionality for Home Assistant entities, allowing users to add entities
/// to various iOS platform features and connected devices.
///
/// This class provides two main capabilities:
/// 1. Determining which actions are available for a given entity based on its type and domain
/// 2. Executing the selected action to add the entity to the chosen platform feature
final class EntityAddToHandler {
    weak var webViewController: WebViewControllerProtocol?

    init(webViewController: WebViewControllerProtocol? = nil) {
        self.webViewController = webViewController
    }

    /// Returns the list of available actions for the specified entity.
    ///
    /// The available actions depend on the entity's domain and current system state.
    ///
    /// - Parameter entityId: The entity ID to get available actions for (e.g., "light.living_room")
    /// - Returns: Promise that resolves to a list of actions that can be performed for this entity
    func actionsForEntity(entityId: String) -> Promise<[any EntityAddToAction]> {
        Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async {
                var actions: [any EntityAddToAction] = []

                // Extract the domain from the entity ID
                let domain = Domain(entityId: entityId)

                // CarPlay is available on iPhone only (not iPad) for supported domains
                #if !targetEnvironment(macCatalyst)
                if !Current.isCatalyst, UIDevice.current.userInterfaceIdiom == .phone {
                    let isCarPlaySupported = domain.map { CarPlaySupportedDomains.all.contains($0) } ?? false
                    if isCarPlaySupported {
                        actions.append(CarPlayQuickAccessAction())
                    }
                }
                #endif

                // Watch is available on iPhone for supported domains
                #if os(iOS)
                if !Current.isCatalyst {
                    let isWatchSupported = domain.map { WatchSupportedDomains.all.contains($0) } ?? false
                    if isWatchSupported {
                        actions.append(WatchItemAction())
                    }
                }
                #endif

                // Widgets are available on all platforms
                actions.append(CustomWidgetAction())

                seal.fulfill(actions)
            }
        }
    }

    /// Executes the specified action to add the entity to the chosen platform feature.
    ///
    /// This function performs the appropriate operation based on the action type.
    ///
    /// - Parameters:
    ///   - action: The action to execute
    ///   - entityId: The entity ID to add (e.g., "light.living_room")
    /// - Returns: Promise that resolves when the action is executed
    func execute(action: any EntityAddToAction, entityId: String) -> Promise<Void> {
        Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    seal.reject(EntityAddToError.handlerDeallocated)
                    return
                }

                guard let webViewController else {
                    seal.reject(EntityAddToError.webViewControllerUnavailable)
                    return
                }

                let actionType = EntityAddToActionType(rawValue: action.actionType)

                switch actionType {
                case .carPlayQuickAccess:
                    addToCarPlayQuickAccess(entityId: entityId, webViewController: webViewController)
                    seal.fulfill(())

                case .watchItem:
                    addToWatchItems(entityId: entityId, webViewController: webViewController)
                    seal.fulfill(())

                case .customWidget:
                    openWidgetBuilder(
                        actionType: actionType,
                        entityId: entityId,
                        webViewController: webViewController
                    )
                    seal.fulfill(())

                case .none:
                    seal.reject(EntityAddToError.unknownActionType)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func addToCarPlayQuickAccess(entityId: String, webViewController: WebViewControllerProtocol) {
        // Navigate to CarPlay configuration screen
        Current.Log.info("Adding entity \(entityId) to CarPlay quick access")
        let viewModel = CarPlayConfigurationViewModel(prefilledItem: .init(
            id: entityId,
            serverId: webViewController.server.identifier.rawValue,
            type: .entity
        ))
        let carPlaySettingsView = CarPlayConfigurationView(needsNavigationController: true, viewModel: viewModel)
        webViewController.presentOverlayController(
            controller: carPlaySettingsView.embeddedInHostingController(),
            animated: true
        )
    }

    private func addToWatchItems(entityId: String, webViewController: WebViewControllerProtocol) {
        // Navigate to Watch configuration screen
        Current.Log.info("Adding entity \(entityId) to Watch")
        let viewModel = WatchConfigurationViewModel(prefilledItem: .init(
            id: entityId,
            serverId: webViewController.server.identifier.rawValue,
            type: .entity
        ))
        let watchSettingsView = WatchConfigurationView(needsNavigationController: true, viewModel: viewModel)
            .preferredColorScheme(.dark)
        let viewController = watchSettingsView.embeddedInHostingController()
        viewController.overrideUserInterfaceStyle = .dark
        webViewController.presentOverlayController(controller: viewController, animated: true)
    }

    private func openWidgetBuilder(
        actionType: EntityAddToActionType?,
        entityId: String,
        webViewController: WebViewControllerProtocol
    ) {
        // Navigate to the widget builder/configuration screen
        // TODO: Pre-select the entity and widget type when WidgetBuilderView supports it
        Current.Log.info("Opening widget builder for \(String(describing: actionType)) with entity \(entityId)")
        let widgetBuilderView = WidgetBuilderView()
            .embeddedInHostingController()
        webViewController.presentOverlayController(controller: widgetBuilderView, animated: true)
    }
}

// MARK: - Error Types

extension EntityAddToError {
    static let handlerDeallocated = EntityAddToError.decodingFailed
    static let webViewControllerUnavailable = EntityAddToError.decodingFailed
    static let unknownActionType = EntityAddToError.invalidPayload
}
