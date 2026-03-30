import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayDomainsListViewModel {
    private let condensedDomainsPerRow = 6
    private let overrideCoverIcon = MaterialDesignIcons.garageLockIcon
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

        if #available(iOS 26.0, *) {
            templateProvider?.updateDomainItems(items: condensedDomainItems(domains: domains))
        } else {
            templateProvider?.updateDomainItems(items: listItems(domains: domains))
        }
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

    @available(iOS 26.0, *)
    private func condensedDomainItems(domains: [Domain]) -> [any CPListTemplateItem] {
        stride(from: 0, to: domains.count, by: condensedDomainsPerRow).map { startIndex in
            let pageDomains = Array(domains[startIndex ..< min(startIndex + condensedDomainsPerRow, domains.count)])
            let elements = pageDomains.map { domain in
                CPListImageRowItemCondensedElement(
                    image: domainIcon(domain).image(
                        ofSize: CPListImageRowItemCondensedElement.maximumImageSize,
                        color: .haPrimary
                    ),
                    imageShape: .roundedRectangle,
                    title: domain.localizedDescription,
                    subtitle: nil,
                    accessorySymbolName: "chevron.right"
                )
            }

            let item = CPListImageRowItem(
                text: nil,
                condensedElements: elements,
                allowsMultipleLines: true
            )
            item.listImageRowHandler = { [weak self] _, index, completion in
                guard pageDomains.indices.contains(index) else {
                    completion()
                    return
                }
                self?.listItemHandler(domain: pageDomains[index].rawValue)
                completion()
            }
            return item
        }
    }

    private func listItems(domains: [Domain]) -> [any CPListTemplateItem] {
        domains.map { domain in
            let listItem = CPListItem(
                text: domain.localizedDescription,
                detailText: nil,
                image: domainIcon(domain).carPlayIcon()
            )
            listItem.accessoryType = .disclosureIndicator
            listItem.handler = { [weak self] _, completion in
                self?.listItemHandler(domain: domain.rawValue)
                completion()
            }
            return listItem
        }
    }

    private func domainIcon(_ domain: Domain) -> MaterialDesignIcons {
        domain == .cover ? overrideCoverIcon : domain.icon()
    }
}
