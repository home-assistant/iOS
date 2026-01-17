import Foundation
import GRDB
import PromiseKit
import HAKit

public protocol PanelsUpdaterProtocol {
    func update()
}

final class PanelsUpdater: PanelsUpdaterProtocol {
    static var shared = PanelsUpdater()

    private var tokens: [(promise: Promise<HAPanels>, cancel: () -> Void)?] = []

    public func update() {
        tokens.forEach({ $0?.cancel() })
        tokens = []
        for server in Current.servers.all {
            let request = Current.api(for: server)?.connection.send(.panels())
            tokens.append(request)
            request?.promise.done({ [weak self] panels in
                self?.saveInDatabase(panels, server: server)
            }).cauterize()
        }
    }

    private func saveInDatabase(_ panels: HAPanels, server: Server) {
        let appPanels = panels.allPanels.map { panel in
            AppPanel(
                serverId: server.identifier.rawValue,
                icon: panel.icon,
                title: panel.title,
                path: panel.path,
                component: panel.component,
                showInSidebar: panel.showInSidebar
            )
        }

        do {
            try Current.database.write { db in
                try AppPanel.filter(Column(DatabaseTables.AppPanel.serverId.rawValue) == server.identifier.rawValue)
                    .deleteAll(db)
                for panel in appPanels {
                    try panel.save(db)
                }
            }
        } catch {
            Current.Log.error("Error saving panels in database: \(error)")
        }
    }
}


public extension HAConnection {
    /// Send a request
    ///
    /// Wraps a normal request send in a Promise.
    ///
    /// - SeeAlso: `HAConnection.send(_:completion:)`
    /// - Parameter request: The request to send
    /// - Returns: The promies for the request, and a block to cancel
    func send(_ request: HARequest) -> (promise: Promise<HAData>, cancel: () -> Void) {
        let (promise, seal) = Promise<HAData>.pending()
        let token = send(request, completion: { result in
            switch result {
            case let .success(data): seal.fulfill(data)
            case let .failure(error): seal.reject(error)
            }
        })
        return (promise: promise, cancel: token.cancel)
    }

    /// Send a request with a concrete response type
    ///
    /// Wraps a typed request send in a Promise.
    ///
    /// - SeeAlso: `HAConnection.send(_:completion:)`
    /// - Parameter request: The request to send
    /// - Returns: The promise for the request, and a block to cancel
    func send<T>(_ request: HATypedRequest<T>) -> (promise: Promise<T>, cancel: () -> Void) {
        let (promise, seal) = Promise<T>.pending()
        let token = send(request, completion: { result in
            switch result {
            case let .success(data): seal.fulfill(data)
            case let .failure(error): seal.reject(error)
            }
        })
        return (promise: promise, cancel: token.cancel)
    }
}
