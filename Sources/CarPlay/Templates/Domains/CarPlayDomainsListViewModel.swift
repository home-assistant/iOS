import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayDomainsListViewModel {
    private var entities: HACache<HACachedStates>?
    private var entitiesSubscriptionToken: HACancellable?
    private var domainsCurrentlyInList: [Domain] = []

    weak var templateProvider: CarPlayDomainsListTemplate?

    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    func cancelSubscriptionToken() {
        entitiesSubscriptionToken?.cancel()
    }

    func update() {
        guard !Current.servers.all.isEmpty else {
            templateProvider?.template.updateSections([])
            return
        }

        let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first

        guard let server else { return }
        entities = Current.api(for: server).connection.caches.states

        let entityDomains = Set(entities?.value?.all.map(\.domain) ?? [])
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

        guard entitiesSubscriptionToken == nil else { return }
        entitiesSubscriptionToken = entities?.subscribe { [weak self] _, _ in
            self?.update()
        }
    }

    func listItemHandler(domain: String) {
        guard let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first,
              let entitiesCachedStates = entities else { return }
        let entitiesListTemplate = CarPlayEntitiesListTemplate.build(
            title: Domain(rawValue: domain)?.localizedDescription ?? domain,
            filterType: .domain(domain),
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )

        templateProvider?.presentEntitiesList(template: entitiesListTemplate)
    }
}
