//
//  ClientEventStore.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/18/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift

public struct ClientEventStore {
    public var addEvent: (ClientEvent) -> Void = { event in
        let realm = Current.realm()
        do {
            try realm.write {
                realm.add(event)
            }
        } catch {
            print("Error writing client event: \(error)")
        }
    }

    public var getEvents: () -> Results<ClientEvent> = {
        let realm = Current.realm()
        return realm.objects(ClientEvent.self).sorted(byKeyPath: "date", ascending: false)
    }

    public var clearAllEvents: () -> Void = {
        let realm = Current.realm()

        do {
            try realm.write {
                realm.delete(realm.objects(ClientEvent.self))
            }
        } catch {
            print("Error writing client event: \(error)")
        }
    }
}
