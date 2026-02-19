import Foundation
import PromiseKit
@preconcurrency import Shared
import SwiftUI

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
        let carPlaySettingsView = CarPlayConfigurationView(viewModel: viewModel)
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
        Current.Log.info("Opening widget selection for entity \(entityId)")

        let serverId = webViewController.server.identifier.rawValue

        let selectionView = WidgetSelectionView(
            entityId: entityId,
            serverId: serverId
        ) { [weak self] selectedWidget in
            self?.handleWidgetSelection(
                widget: selectedWidget,
                entityId: entityId,
                serverId: serverId,
                webViewController: webViewController
            )
        }
        .modify { view in
            if Current.isCatalyst {
                view.toolbar(content: {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            webViewController.dismissOverlayController(animated: true, completion: nil)
                        }
                    }
                })
            } else {
                view
            }
        }

        let hostingController = selectionView.embeddedInHostingController()

        if Current.isCatalyst {
            let navigationController = UINavigationController(rootViewController: hostingController)
            webViewController.presentOverlayController(controller: navigationController, animated: true)
        } else {
            // Present as a bottom sheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
            webViewController.presentOverlayController(controller: hostingController, animated: true)
        }
    }

    private func handleWidgetSelection(
        widget: CustomWidget?,
        entityId: String,
        serverId: String,
        webViewController: WebViewControllerProtocol
    ) {
        // Small delay to allow the selection sheet to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let widget {
                // Add entity to existing widget
                self.addEntityToWidget(
                    widget: widget,
                    entityId: entityId,
                    serverId: serverId,
                    webViewController: webViewController
                )
            } else {
                // Create new widget with the entity pre-filled
                self.createNewWidgetWithEntity(
                    entityId: entityId,
                    serverId: serverId,
                    webViewController: webViewController
                )
            }
        }
    }

    private func addEntityToWidget(
        widget: CustomWidget,
        entityId: String,
        serverId: String,
        webViewController: WebViewControllerProtocol
    ) {
        Current.Log.info("Adding entity \(entityId) to widget '\(widget.name)'")

        // Create a new MagicItem for the entity
        let newItem = MagicItem(
            id: entityId,
            serverId: serverId,
            type: .entity
        )

        // Create updated widget with the new item
        var updatedWidget = widget
        updatedWidget.items.append(newItem)

        // Save to database
        do {
            try Current.database().write { db in
                try updatedWidget.update(db)
            }

            // Open the widget creation view to let user see and further customize
            let widgetCreationView = WidgetCreationView(widget: updatedWidget) {
                // Reload widgets after changes
            }
            let hostingController = widgetCreationView
                .embeddedInHostingController()

            webViewController.presentOverlayController(controller: hostingController, animated: true)
        } catch {
            Current.Log.error("Failed to add entity to widget: \(error.localizedDescription)")
        }
    }

    private func createNewWidgetWithEntity(
        entityId: String,
        serverId: String,
        webViewController: WebViewControllerProtocol
    ) {
        Current.Log.info("Creating new widget with entity \(entityId)")

        // Create a new widget with the entity pre-filled
        let newItem = MagicItem(
            id: entityId,
            serverId: serverId,
            type: .entity
        )

        let newWidget = CustomWidget(
            id: UUID().uuidString,
            name: "",
            items: [newItem]
        )

        let widgetCreationView = WidgetCreationView(widget: newWidget) {
            // Reload widgets after changes
        }

        let hostingController = widgetCreationView
            .embeddedInHostingController()

        webViewController.presentOverlayController(controller: hostingController, animated: true)
    }
}

// MARK: - Error Types

extension EntityAddToError {
    static let handlerDeallocated = EntityAddToError.decodingFailed
    static let webViewControllerUnavailable = EntityAddToError.decodingFailed
    static let unknownActionType = EntityAddToError.invalidPayload
}
