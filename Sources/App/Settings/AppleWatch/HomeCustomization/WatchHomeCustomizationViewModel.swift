//
//  WatchHomeCustomizationViewModel.swift
//  App
//
//  Created by Bruno Pantaleão on 07/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Shared
import GRDB

final class WatchHomeCustomizationViewModel: ObservableObject {
    @Published var watchConfig: WatchConfig = WatchConfig(showAssist: true, items: [])
    private var dbQueue: DatabaseQueue?

    @MainActor
    func loadWatchConfig() {
        do {
            dbQueue = try DatabaseQueue(path: Constants.grdbFile.path)
            guard let dbQueue else { return }

            createTableIfNeeded()

            if let config: WatchConfig = try dbQueue.read({ db in
                do {
                    return try WatchConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching watch config \(error)")
                }
                return nil
            }) {
                self.watchConfig = config
                print(config)
            } else {
                Current.Log.error("No watch config found")
                convertLegacyActionsToWatchConfig()
            }
        } catch {
            Current.Log.error("Failed to acces database (GRDB)")
        }
    }

    private func createTableIfNeeded() {
        guard let dbQueue else { return }
        do {
            try dbQueue.write { db in
                try db.create(table: "watchConfig") { t in
                    t.primaryKey("id", .text).notNull()
                    t.column("showAssist", .boolean).notNull()
                    t.column("items", .jsonText).notNull()
                }
            }
        } catch {
            Current.Log.error(error.localizedDescription)
        }
    }

    @MainActor
    private func convertLegacyActionsToWatchConfig() {
        guard let dbQueue else { return }

        let actionResults = Current.realm().objects(Action.self)
        if actionResults.isEmpty {
            let newWatchConfig = WatchConfig()
            do {
                try dbQueue.write { db in
                    try newWatchConfig.insert(db)
                }
            } catch let error {
                Current.Log.error("Failed to save initial watch config, error: \(error)")
                fatalError()
            }
        } else {
            let newWatchActionItems = actionResults.sorted(by: { $0.Position < $1.Position }).filter({ $0.showInWatch }).map { action in
                WatchItem(id: action.ID, type: .action(.init(id: action.ID, name: action.Text, iconName: action.IconName, backgroundColor: action.BackgroundColor, textColor: action.TextColor, iconColor: action.IconColor)))
            }

            var newWatchConfig = WatchConfig()
            newWatchConfig.items = newWatchActionItems
            do {
                try dbQueue.write { db in
                    try newWatchConfig.insert(db)
                }
                loadWatchConfig()
            } catch let error {
                Current.Log.error("Failed to migrate actions to watch config, error: \(error)")
                fatalError()
            }
        }
    }
}
