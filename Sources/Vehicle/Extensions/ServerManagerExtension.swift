//
//  ServerManagerExtension.swift
//  App
//
//  Created by Luis Lopes on 06/03/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import Shared

extension ServerManager {
    public func isConnected() -> Bool {
        return all.contains(where: { isConnected(server: $0) })
    }
    
    public func isConnected(server : Server) -> Bool{
        switch Current.api(for: server).connection.state {
        case .ready(version: _):
            return true
        default:
            return false
        }
    }
    
    public func getServer(id : Identifier<Server>? = nil) -> Server? {
        guard let id = id else {
            return all.first(where: {isConnected(server: $0)} )
        }
        return server(for: id)
    }
}
