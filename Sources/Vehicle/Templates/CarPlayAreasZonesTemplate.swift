import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAreasZonesTemplate: CarPlayTemplateProvider {
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?

    private var request: HACancellable?
    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    init() {
        self.template = CPListTemplate(title: "", sections: [])
        template.tabImage = MaterialDesignIcons.sofaIcon.carPlayIcon(color: Constants.tintColor)
        template.tabTitle = L10n.Carplay.Navigation.Tab.areas
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == self.template {
            request?.cancel()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
    }

    func update() {
        guard let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first else {
            template.updateSections([])
            return
        }

        let api = Current.api(for: server)

        request?.cancel()
        request = api.connection.send(HATypedRequest<[HAAreaResponse]>.fetchAreas(), completion: { [weak self] result in
            switch result {
            case let .success(data):
                self?.updateAreas(data)
            case let .failure(error):
                self?.template.updateSections([])
                Current.Log.error(userInfo: ["Failed to retrieve areas": error.localizedDescription])
            }
        })
    }

    private func updateAreas(_ areas: [HAAreaResponse]) {
        let items = areas.sorted(by: { a1, a2 in
            a1.name < a2.name
        }).map { area in
            let item = CPListItem(text: area.name, detailText: nil)
            item.accessoryType = .disclosureIndicator
            return item
        }

        template.updateSections([.init(items: items)])
    }
}
