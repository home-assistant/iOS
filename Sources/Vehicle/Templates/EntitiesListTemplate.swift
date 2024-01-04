import CarPlay
import Foundation
import HAKit
import PromiseKit
import Shared

@available(iOS 16.0, *)
class EntitiesListTemplate {
    private let entityIconSize: CGSize = .init(width: 64, height: 64)
    private var stateSubscriptionToken: HACancellable?
    private let domain: String
    private var server: Server
    private let entitiesCachedStates: HACache<Set<HAEntity>>
    private var listTemplate: CPListTemplate?
    private var currentPage: Int = 0

    /// Maximum number of items per page minus pagination buttons
    private var itemsPerPage: Int = CPListTemplate.maximumItemCount

    private var entitiesSubscriptionToken: HACancellable?

    init(domain: String, server: Server, entitiesCachedStates: HACache<Set<HAEntity>>) {
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
            listTemplate = CPListTemplate(title: "", sections: [])
            return listTemplate!
        }
    }

    private func updateListItems() {
        guard let entities = entitiesCachedStates.value else { return }
        let entitiesSorted = entities
            .sorted(by: { $0.attributes.friendlyName ?? $0.entityId < $1.attributes.friendlyName ?? $1.entityId })

        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, entitiesSorted.count)
        let entitiesToShow = Array(entitiesSorted[startIndex ..< endIndex])

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
            listTemplate?.trailingNavigationBarButtons = getPageButtons(
                endIndex: endIndex,
                currentPage: currentPage,
                totalCount: entitiesSorted.count
            )
        }

        listTemplate?.updateSections([CPListSection(items: items)])
    }

    func getPageButtons(endIndex: Int, currentPage: Int, totalCount: Int) -> [CPBarButton] {
        var barButtons: [CPBarButton] = []

        let forwardImage = UIImage(systemName: "arrow.forward")!
        if endIndex < totalCount {
            barButtons.append(CPBarButton(
                image: forwardImage,
                handler: { _ in
                    self.changePage(to: .Next)
                }
            ))
        } else {
            barButtons
                .append(CPBarButton(
                    image: UIImage(size: forwardImage.size, color: UIColor.clear),
                    handler: nil
                ))
        }

        let backwardImage = UIImage(systemName: "arrow.backward")!
        if currentPage > 0 {
            barButtons.append(CPBarButton(
                image: backwardImage,
                handler: { _ in
                    self.changePage(to: .Previous)
                }
            ))
        } else {
            barButtons
                .append(CPBarButton(
                    image: UIImage(size: backwardImage.size, color: UIColor.clear),
                    handler: nil
                ))
        }

        return barButtons
    }

    func changePage(to: GridPage) {
        switch to {
        case .Next:
            currentPage += 1
        case .Previous:
            currentPage -= 1
        }
        updateListItems()
    }
}

enum GridPage {
    case Next
    case Previous
}

enum CPEntityError: Error {
    case unknown
}
