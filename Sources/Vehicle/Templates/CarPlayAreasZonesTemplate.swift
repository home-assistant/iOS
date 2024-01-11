import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAreasZonesTemplate: CarPlayTemplateProvider {
    private var childTemplateProvider: (any CarPlayTemplateProvider)?

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
        childTemplateProvider?.templateWillDisappear(template: template)
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
        childTemplateProvider?.templateWillAppear(template: template)
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
                self?.fetchEntitiesForAreas(data, server: server)
            case let .failure(error):
                self?.template.updateSections([])
                Current.Log.error(userInfo: ["Failed to retrieve areas": error.localizedDescription])
            }
        })
    }

    private func fetchEntitiesForAreas(_ areas: [HAAreaResponse], server: Server) {
        let api = Current.api(for: server)
        
        request?.cancel()
        request = api.connection.send(HATypedRequest<[HAEntityAreaResponse]>.fetchEntitiesWithAreas(), completion: { [weak self] result in
            switch result {
            case let .success(data):
                self?.updateAreas(areas, areasAndEntities: data, server: server)
            case let .failure(error):
                self?.template.updateSections([])
                Current.Log.error(userInfo: ["Failed to retrieve areas and entities": error.localizedDescription])
            }
        })
    }

    private func updateAreas(_ areas: [HAAreaResponse], areasAndEntities: [HAEntityAreaResponse], server: Server) {
        let items = areas.sorted(by: { a1, a2 in
            a1.name < a2.name
        }).map { area in
            let entityIdsForAreaId = areasAndEntities.filter({ $0.areaId == area.areaId }).compactMap({ $0.entityId })
            let item = CPListItem(text: area.name, detailText: nil)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.listItemHandler(area: area, entityIdsForAreaId: entityIdsForAreaId, server: server)
                completion()
            }
            return item
        }

        template.updateSections([.init(items: items)])
    }

    private func listItemHandler(area: HAAreaResponse, entityIdsForAreaId: [String], server: Server) {
        let entitiesCachedStates = Current.api(for: server).connection.caches.states
        let entitiesListTemplate = CarPlayEntitiesListTemplate(
            title: area.name,
            filterType: .areaId(entityIds: entityIdsForAreaId),
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )

        entitiesListTemplate.interfaceController = interfaceController

        childTemplateProvider = entitiesListTemplate
        interfaceController?.pushTemplate(
            entitiesListTemplate.template,
            animated: true,
            completion: nil
        )
    }
}
