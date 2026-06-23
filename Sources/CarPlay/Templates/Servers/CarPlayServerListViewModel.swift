import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayServerListViewModel {
    weak var templateProvider: CarPlayServersListTemplate?
    weak var interfaceController: CPInterfaceController?

    func removeServerObserver() {
        Current.servers.remove(observer: self)
    }

    func addServerObserver() {
        removeServerObserver()
        Current.servers.add(observer: self)
    }

    func setServer(server: Server) {
        CarPlayPreferredServer.select(server)
        templateProvider?.update()
        templateProvider?.sceneDelegate?.setup()
    }
}

@available(iOS 16.0, *)
extension CarPlayServerListViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        guard let server = serverManager.serverOrFirstIfAvailable(
            for: Identifier<Server>(rawValue: CarPlayPreferredServer.id)
        ) else {
            if interfaceController?.presentedTemplate != nil {
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            } else {
                templateProvider?.showNoServerAlert()
            }
            return
        }
        setServer(server: server)
    }
}
