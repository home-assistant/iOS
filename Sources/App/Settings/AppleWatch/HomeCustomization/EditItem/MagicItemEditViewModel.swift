//
//  MagicItemEditViewModel.swift
//  App
//
//  Created by Bruno Pantaleão on 13/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Shared
import PromiseKit

final class MagicItemEditViewModel: ObservableObject {
    @Published var item: MagicItem
    @Published var info: MagicItem.Info?

    private var actions: [Action] = []
    private var scriptsPerServer: [String: [HAScript]] = [:]

    init(item: MagicItem) {
        self.item = item
    }

    @MainActor
    func loadActionsAndScripts() {
        actions = Current.realm().objects(Action.self).sorted(by: { $0.Position < $1.Position })

        Current.servers.all.forEach { [weak self] server in
            let key = HAScript.cacheKey(serverId: server.identifier.rawValue)
            (Current.diskCache.value(for: key) as Promise<[HAScript]>).pipe { result in
                switch result {
                case let .fulfilled(scripts):
                    self?.scriptsPerServer[server.identifier.rawValue] = scripts
                    self?.loadMagicInfo()
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to retrieve scripts from cache while adding watch item, error: \(error.localizedDescription)"
                        )
                }
            }
        }
    }

    func loadMagicInfo() {
        switch item.type {
        case .action:
            guard let actionItem = actions.first(where: { $0.ID == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Action info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                info = .init(id: UUID().uuidString, name: "Unknown Action", iconName: "")
                return
            }
            info = .init(
                id: actionItem.ID,
                name: actionItem.Text,
                iconName: actionItem.IconName,
                customization: .init(
                    iconColor: actionItem.IconColor,
                    textColor: actionItem.TextColor,
                    backgroundColor: actionItem.BackgroundColor,
                    requiresConfirmation: false
                )
            )
        case .script:
            guard let serverId = item.serverId,
                  let scriptsForServer = scriptsPerServer[serverId],
                  let scriptItem = scriptsForServer.first(where: { $0.id == item.id }) else {
                Current.Log
                    .error(
                        "Failed to get magic item Script info for item id: \(item.id), server id: \(String(describing: item.serverId))"
                    )
                info = .init(id: UUID().uuidString, name: "Unknown Script", iconName: "")
                return
            }

            info = .init(
                id: scriptItem.id,
                name: scriptItem.name ?? "Unknown",
                iconName: scriptItem.iconName ?? "",
                customization: item.customization
            )
        }
    }
}
