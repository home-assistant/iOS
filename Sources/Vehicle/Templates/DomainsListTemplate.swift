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
        var domains = Set(entitiesCachedStates.value?.all.map(\.domain) ?? [])
        domains = domains.filter { CarPlayDomain(domain: $0).isSupported }
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

enum CarPlayDomain: CaseIterable {
    case button
    case cover
    case input_boolean
    case input_button
    case light
    case lock
    case scene
    case script
    case `switch`
    case unsupported

    var domain: String {
        switch self {
        case .button: return "button"
        case .cover: return "cover"
        case .input_boolean: return "input_boolean"
        case .input_button: return "input_button"
        case .light: return "light"
        case .lock: return "lock"
        case .scene: return "scene"
        case .script: return "script"
        case .switch: return "switch"
        case .unsupported: return "unsupported"
        }
    }

    var localizedDescription: String {
        switch self {
        case .button: return L10n.Carplay.Labels.buttons
        case .cover: return L10n.Carplay.Labels.covers
        case .input_boolean: return L10n.Carplay.Labels.inputBooleans
        case .input_button: return L10n.Carplay.Labels.inputButtons
        case .light: return L10n.Carplay.Labels.lights
        case .lock: return L10n.Carplay.Labels.locks
        case .scene: return L10n.Carplay.Labels.scenes
        case .script: return L10n.Carplay.Labels.scripts
        case .switch: return L10n.Carplay.Labels.switches
        case .unsupported: return ""
        }
    }

    var isSupported: Bool {
        self != .unsupported
    }

    init(domain: String) {
        self = Self.allCases.first(where: { $0.domain == domain }) ?? .unsupported
    }
}
