import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
class CarPlayDomainsListTemplate: CarPlayTemplateProvider {
    private var domainList: [String] = []
    private var childTemplateProvider: CarPlayTemplateProvider?
    private var entities: HACache<HACachedStates>?
    private var entitiesSubscriptionToken: HACancellable?

    weak var interfaceController: CPInterfaceController?

    var template: CPTemplate

    init() {
        let listTemplate = CPListTemplate(title: L10n.About.Logo.title, sections: [])
        listTemplate.emptyViewSubtitleVariants = [L10n.Carplay.Labels.emptyDomainList]
        self.template = listTemplate
    }

    func update() {
        guard !Current.servers.all.isEmpty else {
            (template as? CPListTemplate)?.updateSections([])
            return
        }

        var server = Current.servers.all.first
        if let serverIdentifier = prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey),
           let selectedServer = Current.servers.server(forServerIdentifier: serverIdentifier) {
            server = selectedServer
        }

        guard let server else { return }
        entities = Current.api(for: server).connection.caches.states

        var items: [CPListItem] = []
        let entityDomains = Set(entities?.value?.all.map(\.domain) ?? [])
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
                self?.listItemHandler(domain: domain.rawValue, server: server, entitiesCachedStates: self?.entities)
                completion()
            }

            items.append(listItem)
        }

        domainList = domains
        (template as? CPListTemplate)?.updateSections([CPListSection(items: items)])
        template.tabTitle = L10n.Carplay.Navigation.Tab.domains
        template.tabImage = MaterialDesignIcons.devicesIcon.image(ofSize: .init(width: 64, height: 64), color: nil)

        guard entitiesSubscriptionToken == nil else { return }
        entitiesSubscriptionToken = entities?.subscribe { [weak self] _, _ in
            self?.update()
        }
    }

    func templateWillDisappear(template: CPTemplate) {
        if self.template == template {
            entitiesSubscriptionToken?.cancel()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
    }

    private func listItemHandler(domain: String, server: Server, entitiesCachedStates: HACache<HACachedStates>?) {
        guard let entitiesCachedStates else { return }
        let entitiesListTemplate = CarPlayEntitiesListTemplate(
            title: Domain(rawValue: domain)?.localizedDescription ?? domain,
            domain: domain,
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )

        entitiesListTemplate.interfaceController = interfaceController

        childTemplateProvider = entitiesListTemplate
        interfaceController?.pushTemplate(
            entitiesListTemplate.getTemplate(),
            animated: true,
            completion: nil
        )
    }
}
