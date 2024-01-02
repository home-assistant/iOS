import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
class DomainsListTemplate {
    private let title: String
    private let entitiesCachedStates: HACache<HACachedStates>
    private let serverButtonHandler: CPBarButtonHandler?
    private let server: Server

    private var domainList: Set<String> = []
    private var listTemplate: CPListTemplate?

    private let allowedDomains: [String] = [
        "light",
        "switch",
        "button",
        "cover",
        "input_boolean",
        "input_button",
        "lock",
        "scene",
        "script"
    ]

    weak var interfaceController: CPInterfaceController?

    var template: CPListTemplate {
        guard let listTemplate = listTemplate else {
            listTemplate = CPListTemplate(title: title, sections: [])
            listTemplate?.emptyViewSubtitleVariants = [L10n.Carplay.Labels.emptyDomainList]
            return listTemplate!
        }
        return listTemplate
    }

    init(
        title: String,
        entities: HACache<HACachedStates>,
        serverButtonHandler: CPBarButtonHandler? = nil,
        server: Server
    ) {
        self.title = title
        self.entitiesCachedStates = entities
        self.serverButtonHandler = serverButtonHandler
        self.server = server
    }

    func setServerListButton(show: Bool) {
        if show {
            listTemplate?
                .trailingNavigationBarButtons =
                [CPBarButton(title: L10n.Carplay.Labels.servers, handler: serverButtonHandler)]
        } else {
            listTemplate?.trailingNavigationBarButtons.removeAll()
        }
    }

    func updateSections() {

        var items: [CPListItem] = []
        var domains = Set(entitiesCachedStates.value?.all.map { $0.domain } ?? [])
        domains = domains.filter { allowedDomains.contains($0) }
        domains = Set(domains.sorted(by: { d1, d2 in
            d1 < d2
        }))

        domains.forEach { domain in
            let itemTitle = domain
            let listItem = CPListItem(
                text: itemTitle,
                detailText: nil,
                image: HAEntity.icon(
                    forDomain: domain,
                    size: CPListItem.maximumImageSize
                )
            )
            listItem.accessoryType = CPListItemAccessoryType.disclosureIndicator
            listItem.handler = { [weak self] _, completion in
                self?.listItemHandler(domain: domain)
                completion()
            }

            items.append(listItem)
        }

        domainList = domains
        listTemplate?.updateSections([CPListSection(items: items)])
    }

    private func listItemHandler(domain: String) {
        let itemTitle = domain
        let entitiesGridTemplate = EntitiesListTemplate(
            title: itemTitle,
            domain: domain,
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )

        interfaceController?.pushTemplate(
            entitiesGridTemplate.getTemplate(),
            animated: true,
            completion: nil
        )
    }
}
