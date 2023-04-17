import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
class DomainsListTemplate {
    private var title: String
    private var listTemplate: CPListTemplate?
    private var entities: [HAEntity]
    private let listItemHandler: (String, [HAEntity]) -> Void
    private var serverButtonHandler: CPBarButtonHandler?
    private var domainList: [String] = []
    
    init(title: String, entities: [HAEntity], ic: CPInterfaceController,
        listItemHandler: @escaping (String, [HAEntity]) -> Void,
        serverButtonHandler: CPBarButtonHandler? = nil)
    {
        self.title = title
        self.entities = entities
        self.listItemHandler = listItemHandler
        self.serverButtonHandler = serverButtonHandler
    }
    
    public func getTemplate() -> CPListTemplate {
        guard let listTemplate = listTemplate else {
            listTemplate = CPListTemplate(title: title, sections: [])
            listTemplate?.emptyViewSubtitleVariants = [L10n.Carplay.Labels.emptyDomainList]
            return listTemplate!
        }
        return listTemplate
    }
    
    public func entitiesUpdate(updateEntities: [HAEntity]) {
        entities = updateEntities
        updateSection()
    }
    
    func setServerListButton(show: Bool) {
        if show {
            listTemplate?.trailingNavigationBarButtons = [CPBarButton(title: L10n.Carplay.Labels.servers, handler: serverButtonHandler)]
        } else {
            listTemplate?.trailingNavigationBarButtons.removeAll()
        }
    }
    
    func updateSection() {
        let allUniqueDomains = entities.unique(by: {$0.domain})
        let domainsSorted = allUniqueDomains.sorted { $0.domain < $1.domain }
        let domains = domainsSorted.map { $0.domain }
        
        guard domainList != domains else {
            return
        }
    
        var items: [CPListItem] = []

        for domain in domains {
                        
            let itemTitle = CarPlayDelegate.SUPPORTED_DOMAINS_WITH_STRING[domain] ?? domain
            let listItem = CPListItem(text: itemTitle,
                                      detailText: nil,
                                      image: HAEntity.getIconForDomain(domain: domain, size: CPListItem.maximumImageSize))
            listItem.accessoryType = CPListItemAccessoryType.disclosureIndicator
            listItem.handler = { [weak self] item, completion in
                if let entitiesForSelectedDomain = self?.getEntitiesForDomain(domain: domain) {
                    self?.listItemHandler(domain, entitiesForSelectedDomain)
                }
                completion()
            }
            
            items.append(listItem)
        }
        
        domainList = domains
        listTemplate?.updateSections([CPListSection(items: items)])
    }
    
    func getEntitiesForDomain(domain: String) -> [HAEntity] {
        return entities.filter {$0.domain == domain}
    }
}

extension Array {
    func unique<T:Hashable>(by: ((Element) -> (T)))  -> [Element] {
        var set = Set<T>()
        var arrayOrdered = [Element]()
        for value in self {
            let v = by(value)
            if !set.contains(v) {
                set.insert(v)
                arrayOrdered.append(value)
            }
        }
        return arrayOrdered
    }
}
