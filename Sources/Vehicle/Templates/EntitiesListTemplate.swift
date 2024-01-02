import CarPlay
import Foundation
import HAKit
import PromiseKit
import Shared

@available(iOS 16.0, *)
class EntitiesListTemplate {
    private let entityIconSize: CGSize = .init(width: 64, height: 64)
    private var stateSubscriptionToken: HACancellable?
    private let title: String
    private let domain: String
    private var server: Server
    private let entitiesCachedStates: HACache<HACachedStates>
    private var listTemplate: CPListTemplate?
    private var currentPage: Int = 0

    /// Maximum number of items per page minus pagination buttons
    private var itemsPerPage: Int = CPListTemplate.maximumItemCount - 2

    private var entitiesSubscriptionToken: HACancellable?

    init(title: String, domain: String, server: Server, entitiesCachedStates: HACache<HACachedStates>) {
        self.title = title
        self.domain = domain
        self.server = server
        self.entitiesCachedStates = entitiesCachedStates
    }

    public func getTemplate() -> CPListTemplate {
        defer {
            updateListItems()
            entitiesSubscriptionToken = entitiesCachedStates.subscribe { [weak self] _, _ in
                self?.updateListItems()
            }
        }

        if let listTemplate = listTemplate {
            return listTemplate
        } else {
            listTemplate = CPListTemplate(title: title, sections: [])
            return listTemplate!
        }
    }

    private func updateListItems() {
        let entities = entitiesCachedStates.value?.all.filter { $0.domain == domain }
        let entitiesSorted = entities?.sorted(by: { $0.attributes.friendlyName ?? $0.entityId < $1.attributes.friendlyName ?? $1.entityId })

        guard let entitiesSorted else { return }

        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, entitiesSorted.count)
        let entitiesToShow = Array(entitiesSorted[startIndex..<endIndex])

        var items: [CPListItem] = []

        entitiesToShow.forEach { entity in
            let item = CPListItem(
                text: entity.attributes.friendlyName ?? entity.entityId,
                detailText: entity.localizedState,
                image: entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon.image(ofSize: entityIconSize, color: nil)
            )
            item.handler = { _, completion in
                firstly { [weak self] () -> Promise<Void> in
                    guard let self = self else { return .init(error: CPEntityError.unknown) }
                    let api = Current.api(for: self.server)
                    return entity.onPress(for: api)
                }.done {
                    completion()
                }.catch { error in
                    Current.Log.error("Received error from callService during onPress call: \(error)")
                }
            }

            items.append(item)
        }

        // Add pagination buttons if needed
        if entitiesSorted.count > itemsPerPage {
            if currentPage > 0 {
                let previousButton = CPListItem(text: L10n.Carplay.Navigation.Button.previous, detailText: nil)
                previousButton.handler = { [weak self] _, completion in
                    self?.currentPage -= 1
                    self?.updateListItems()
                    completion()
                }
                items.insert(previousButton, at: 0)
            }

            if endIndex < entitiesSorted.count {
                let nextButton = CPListItem(text: L10n.Carplay.Navigation.Button.next, detailText: nil)
                nextButton.handler = { [weak self] _, completion in
                    self?.currentPage += 1
                    self?.updateListItems()
                    completion()
                }
                items.append(nextButton)
            }
        }

        listTemplate?.updateSections([CPListSection(items: items)])

    }
}

enum CPEntityError: Error {
    case unknown
}
