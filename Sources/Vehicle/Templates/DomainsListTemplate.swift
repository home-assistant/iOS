import CarPlay
import Foundation
import HAKit
import Shared

protocol CarPlayTemplateProvider {
    var template: CPTemplate { get set }
    func templateWillDisappear(template: CPTemplate)
}

@available(iOS 16.0, *)
class DomainsListTemplate: CarPlayTemplateProvider {
    private let title: String
    private let entitiesCachedStates: HACache<HACachedStates>
    private let serverButtonHandler: CPBarButtonHandler?
    private let server: Server

    private var domainList: [String] = []
    private var childTemplateProvider: CarPlayTemplateProvider?

    weak var interfaceController: CPInterfaceController?

    var template: CPTemplate

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

        let listTemplate = CPListTemplate(title: title, sections: [])
        listTemplate.emptyViewSubtitleVariants = [L10n.Carplay.Labels.emptyDomainList]
        self.template = listTemplate
    }

    func setServerListButton(show: Bool) {
        if show {
            (template as? CPListTemplate)?
                .trailingNavigationBarButtons =
                [CPBarButton(title: L10n.Carplay.Labels.servers, handler: serverButtonHandler)]
        } else {
            (template as? CPListTemplate)?.trailingNavigationBarButtons.removeAll()
        }
    }

    func templateWillDisappear(template: CPTemplate) {
        childTemplateProvider?.templateWillDisappear(template: template)
    }

    func updateSections() {
        var items: [CPListItem] = []
        let entityDomains = Set(entitiesCachedStates.value?.all.map(\.domain) ?? [])
        let domains = entityDomains.filter { Domain(rawValue: $0)?.isCarPlaySupported ?? false }.sorted(by: { d1, d2 in
            d1 < d2
        })

        domains.forEach { domain in
            guard let domain = Domain(rawValue: domain) else { return }
            let itemTitle = domain.localizedDescription
            let listItem = CPListItem(
                text: itemTitle,
                detailText: nil,
                image: domain.icon
            )
            listItem.accessoryType = CPListItemAccessoryType.disclosureIndicator
            listItem.handler = { [weak self] _, completion in
                self?.listItemHandler(domain: domain.rawValue)
                completion()
            }

            items.append(listItem)
        }

        domainList = domains
        (template as? CPListTemplate)?.updateSections([CPListSection(items: items)])
    }

    private func listItemHandler(domain: String) {
        let entitiesListTemplate = EntitiesListTemplate(
            title: Domain(rawValue: domain)?.localizedDescription ?? domain,
            domain: domain,
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )

        childTemplateProvider = entitiesListTemplate
        interfaceController?.pushTemplate(
            entitiesListTemplate.getTemplate(),
            animated: true,
            completion: nil
        )
    }
}
