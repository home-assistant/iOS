import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayDomainsListViewModel {
    private var entities: HACachedStates?
    private var domainsCurrentlyInList: [Domain] = []

    weak var templateProvider: CarPlayDomainsListTemplate?

    var entitiesListTemplate: CarPlayEntitiesListTemplate?

    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    func update(entities: HACachedStates) {
        guard !Current.servers.all.isEmpty else {
            templateProvider?.template.updateSections([])
            return
        }
        self.entities = entities

        let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first

        guard let server else { return }

        let entityDomains = Set(entities.all.map(\.domain))
        let domains = entityDomains.compactMap({ Domain(rawValue: $0) }).filter(\.isCarPlaySupported)
            .sorted(by: { d1, d2 in
                // Fix covers at the top for quick garage door access
                if d1 == .cover {
                    return true
                } else if d2 == .cover {
                    return false
                } else {
                    return d1.localizedDescription < d2.localizedDescription
                }
            })

        // Prevent unecessary update and UI glitch for non-touch screen CarPlay
        guard domainsCurrentlyInList != domains else { return }
        domainsCurrentlyInList = domains

        templateProvider?.updateList(domains: domains)
    }

    func listItemHandler(domain: String) {
        guard let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first,
              let entitiesCachedStates = entities else { return }
        entitiesListTemplate = CarPlayEntitiesListTemplate.build(
            title: Domain(rawValue: domain)?.localizedDescription ?? domain,
            filterType: .domain(domain),
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )
        guard let entitiesListTemplate else { return }
        templateProvider?.presentEntitiesList(template: entitiesListTemplate)
    }
}
