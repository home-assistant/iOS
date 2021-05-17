import Eureka
import Foundation
import Shared
import UIKit

@available(iOS 13, *)
@objc class SettingsSceneDelegate: BasicSceneDelegate {
    private var navigationController: UINavigationController? {
        didSet {
            if let navigationController = navigationController {
                navigationController.delegate = self
                update(navigationController: navigationController)
            }
        }
    }

    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
        .init(
            title: L10n.Settings.NavigationBar.title,
            rootViewController: {
                if #available(iOS 14, *), traitCollection.userInterfaceIdiom == .mac {
                    // root will be set when connecting scene
                    return UINavigationController()
                } else {
                    return UINavigationController(rootViewController: SettingsViewController())
                }
            }()
        )
    }

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        if let navigationController = window?.rootViewController as? UINavigationController {
            self.navigationController = navigationController
        }

        guard let scene = scene as? UIWindowScene else { return }

        #if targetEnvironment(macCatalyst)
        if let titlebar = scene.titlebar {
            if #available(iOS 14, *), scene.traitCollection.userInterfaceIdiom == .mac {
                titlebar.titleVisibility = .visible
                titlebar.toolbarStyle = .preference

                titlebar.toolbar = with(NSToolbar()) {
                    $0.delegate = self

                    if let identifier = SettingsRootDataSource.buttonRows.first?.toolbarItemIdentifier {
                        $0.selectedItemIdentifier = identifier
                        selectItemForIdentifier(identifier)
                    }
                }
            } else {
                titlebar.titleVisibility = .hidden
            }
        }
        #endif
    }

    func pushActions(animated: Bool) {
        if #available(iOS 14, *), window?.traitCollection.userInterfaceIdiom == .mac {
            #if targetEnvironment(macCatalyst)
            let identifier = SettingsRootDataSource.Row.actions.row.toolbarItemIdentifier
            scene?.titlebar?.toolbar?.selectedItemIdentifier = identifier
            selectItemForIdentifier(identifier)
            #endif
        } else {
            navigationController?.pushViewController(
                with(SettingsDetailViewController()) {
                    $0.detailGroup = "actions"
                },
                animated: animated
            )
        }
    }
}

@available(iOS 13, *)
extension SettingsSceneDelegate: UINavigationControllerDelegate {
    private func update(navigationController: UINavigationController) {
        if #available(iOS 14, *), navigationController.traitCollection.userInterfaceIdiom == .mac {
            let shouldBeHidden = navigationController.viewControllers.count <= 1

            if navigationController.isNavigationBarHidden != shouldBeHidden {
                navigationController.setNavigationBarHidden(shouldBeHidden, animated: true)
            }
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        update(navigationController: navigationController)
        navigationController.transitionCoordinator?.animate(
            alongsideTransition: nil,
            completion: { [weak self] context in
                if context.isCancelled {
                    self?.update(navigationController: navigationController)
                }
            }
        )
    }
}

#if targetEnvironment(macCatalyst)
extension SettingsButtonRow {
    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        .init(rawValue: tag ?? title ?? "")
    }
}

extension SettingsSceneDelegate: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsRootDataSource.buttonRows.map(\.toolbarItemIdentifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let tab = SettingsRootDataSource.buttonRows.first(where: { $0.tag == itemIdentifier.rawValue }) else {
            return nil
        }

        return with(NSToolbarItem(itemIdentifier: itemIdentifier)) {
            $0.image = tab.icon?
                .image(ofSize: CGSize(width: 32.0, height: 32.0), color: .black)
                .withRenderingMode(.alwaysTemplate)
            $0.label = tab.title ?? ""
            $0.target = self
            $0.action = #selector(selectItem)
        }
    }

    @objc private func selectItem(_ item: NSToolbarItem) {
        selectItemForIdentifier(item.itemIdentifier)
    }

    fileprivate func selectItemForIdentifier(_ identifier: NSToolbarItem.Identifier) {
        if let viewController = viewController(for: identifier), let navigationController = navigationController {
            scene?.title = SettingsRootDataSource.buttonRows.first(where: { $0.tag == identifier.rawValue })?.title

            // before, so it can be reset by the controller
            navigationController.setToolbarHidden(true, animated: false)

            navigationController.setViewControllers([viewController], animated: false)

            // make sure we're not hiding content by accident
            viewController.loadViewIfNeeded()
            assert(
                (viewController.navigationItem.rightBarButtonItems ?? []).isEmpty &&
                    (viewController.navigationItem.leftBarButtonItems ?? []).isEmpty,
                "we hide the root view controller's navigation bar, so items aren't visible"
            )
        }
    }

    fileprivate func viewController(for itemIdentifier: NSToolbarItem.Identifier) -> UIViewController? {
        guard let tab = SettingsRootDataSource.buttonRows.first(where: { $0.tag == itemIdentifier.rawValue }) else {
            return nil
        }

        guard case let .show(controllerProvider: .callback(builder: block), _) = tab.presentationMode else {
            return nil
        }

        return block()
    }
}
#endif
