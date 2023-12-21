//
//  CarPlaySceneDelegate.swift
//  App
//
//  Created by Bruno Pantaleão on 30/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import CarPlay
import Realm
import RealmSwift
import Shared

@available(iOS 15.0, *)
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var rootTemplate: CPTemplate?
    private let realm = Current.realm()
    private var actionsToken: RLMNotificationToken?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        let actions = realm.objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("Scene == nil")

        actionsToken = actions.observe { [weak self] _ in
            self?.setActions(actions: actions)
        }

        setActions(actions: actions)
    }

    private func setActions(actions: Results<Action>) {
        /* It's called 'tab' because the plan is to put this inside a tab bar
        in the next iterations */
        let actionsTab = CPFavoriteActionsSection().list(for: actions)

        self.rootTemplate = actionsTab
        guard let rootTemplate = self.rootTemplate else { return }
        interfaceController?.setRootTemplate(
            rootTemplate,
            animated: true,
            completion: nil
        )
    }
}

@available(iOS 15.0, *)
extension CarPlaySceneDelegate: CPListTemplateDelegate {
    
    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem) async {
        print(item)
    }
}

