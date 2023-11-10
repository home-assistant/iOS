import CarPlay
import Foundation
import HAKit
import PromiseKit
import Shared

@available(iOS 16.0, *)
class EntitiesGridTemplate {
    
    private let entityIconSize: CGSize = CGSize(width: 64, height: 64)
    private var stateSubscriptionToken: HACancellable?
    private let title: String
    private let domain: String
    private var server: Server
    private var entities: [HAEntity] = []
    private var gridTemplate: CPGridTemplate?
    private var gridPage: Int = 0
    
    enum GridPage {
        case Next
        case Previous
    }
    
    init(title: String, domain: String, server: Server, entities: [HAEntity]) {
        self.title = title
        self.domain = domain
        self.server = server
        self.entities = entities
    }
    
    public func getTemplate() -> CPGridTemplate {
        guard let gridTemplate = gridTemplate else {
            gridTemplate = CPGridTemplate(title: title, gridButtons: getGridButtons())
            return gridTemplate!
        }
        return gridTemplate
    }
    
    func getGridButtons() -> [CPGridButton] {
        var items: [CPGridButton] = []

        let entitiesSorted = entities.sorted(by: { $0.attributes.friendlyName ?? "" < $1.attributes.friendlyName ?? "" })
        
        let entitiesPage = entitiesSorted[(gridPage * CPGridTemplateMaximumItems) ..< min((gridPage * CPGridTemplateMaximumItems) + CPGridTemplateMaximumItems, entitiesSorted.count)]
        
        for entity in entitiesPage {
            let item = CPGridButton(titleVariants: ["\(entity.attributes.friendlyName!) - \(entity.getLocalizedState())"], image: entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon.image(ofSize: entityIconSize, color: nil), handler: { button in
                firstly { () -> Promise<Void> in
                    let api = Current.api(for: self.server)
                    return entity.onPress(for: api)
                }.done {
                }.catch { error in
                    Current.Log.error("Received error from callService during onPress call: \(error)")
                }
            })
            items.append(item)
        }
        return items
    }
    
    func getPageButtons() -> [CPBarButton] {
        var barButtons: [CPBarButton]  = []
        if entities.count > CPGridTemplateMaximumItems {
            let maxPages = entities.count / CPGridTemplateMaximumItems
            if gridPage < maxPages {
                barButtons.append(CPBarButton(image: MaterialDesignIcons.pageNextIcon.image(ofSize: CPButtonMaximumImageSize, color: nil), handler: { CPBarButton in
                    self.changePage(to: .Next)
                }))
            } else {
                barButtons.append(CPBarButton(image: UIImage(size: CPButtonMaximumImageSize, color: UIColor.clear), handler: nil))
            }
            if gridPage > 0 {
                barButtons.append(CPBarButton(image: MaterialDesignIcons.pagePreviousIcon.image(ofSize: CPButtonMaximumImageSize, color: nil), handler: { CPBarButton in
                    self.changePage(to: .Previous)
                }))
            } else {
                barButtons.append(CPBarButton(image: UIImage(size: CPButtonMaximumImageSize, color: UIColor.clear), handler: nil))
            }
        } else {
            gridPage = 0
        }
        return barButtons
    }
    
    func changePage(to: GridPage) {
        switch to {
        case .Next:
            self.gridPage+=1
        case .Previous:
            self.gridPage-=1
        }
        gridTemplate?.updateGridButtons(getGridButtons())
        gridTemplate?.trailingNavigationBarButtons = getPageButtons()
    }
}

@available(iOS 16.0, *)
extension EntitiesGridTemplate: EntitiesStateSubscription {
    public func subscribe() {
        stateSubscriptionToken = Current.api(for: server).connection.caches.states.subscribe { [self] cancellable, cachedStates in
            entities.removeAll { entity in
                !cachedStates.all.contains(where: {$0.entityId == entity.entityId})
            }
            
            for entity in cachedStates.all where entity.domain == domain {
                if let index = entities.firstIndex(where: {$0.entityId == entity.entityId}) {
                    entities[index] = entity
                } else {
                    entities.append(entity)
                }
            }
            
            gridTemplate?.updateGridButtons(getGridButtons())
            gridTemplate?.trailingNavigationBarButtons = getPageButtons()
        }
    }
    
    public func unsubscribe() {
        stateSubscriptionToken?.cancel()
        stateSubscriptionToken = nil
    }
}
