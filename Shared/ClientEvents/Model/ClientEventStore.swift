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
            try realm.reentrantWrite {
                realm.add(event)
            }
        } catch {
            Current.Log.error("Error writing client event: \(error)")
        }

        Current.Log.info(event)
    }

    public var getEvents: () -> Results<ClientEvent> = {
        let realm = Current.realm()
        return realm.objects(ClientEvent.self).sorted(byKeyPath: "date", ascending: false)
    }

    public var clearAllEvents: () -> Void = {
        let realm = Current.realm()

        do {
            try realm.reentrantWrite {
                realm.delete(realm.objects(ClientEvent.self))
            }
        } catch {
            Current.Log.error("Error writing client event: \(error)")
        }
    }
}
