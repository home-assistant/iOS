import CarPlay
import Foundation
import HAKit
import PromiseKit
import Shared

@available(iOS 16.0, *)
final class EntitiesListTemplate {

    enum GridPage {
        case Next
        case Previous
    }

    enum CPEntityError: Error {
        case unknown
    }

    private let title: String
    private let entityIconSize: CGSize = .init(width: 64, height: 64)
    private var stateSubscriptionToken: HACancellable?
    private let domain: String
    private var server: Server
    private let entitiesCachedStates: HACache<HACachedStates>
    private var listTemplate: CPListTemplate?
    private var currentPage: Int = 0

    private var itemsPerPage: Int = CPListTemplate.maximumItemCount
    private var entitiesSubscriptionToken: HACancellable?

    weak var interfaceController: CPInterfaceController?

    init(title: String, domain: String, server: Server, entitiesCachedStates: HACache<HACachedStates>) {
        self.domain = domain
        self.server = server
        self.entitiesCachedStates = entitiesCachedStates
        self.title = title
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
        guard let entities = entitiesCachedStates.value else { return }

        let entitiesFiltered = entities.all.filter { $0.domain == domain }
        let entitiesSorted = entitiesFiltered.sorted(by: { $0.attributes.friendlyName ?? $0.entityId < $1.attributes.friendlyName ?? $1.entityId })

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

                    if let domain = Domain(rawValue: entity.domain), domain == .lock {
                        self.displayLockConfirmation(entity: entity, completion: {
                            entity.onPress(for: api).catch { error in
                                Current.Log.error("Received error from callService during onPress call: \(error)")
                            }
                        })
                        return .value
                    } else {
                        return entity.onPress(for: api)
                    }
                }.done {
                    completion()
                }.catch { error in
                    Current.Log.error("Received error from callService during onPress call: \(error)")
                    completion()
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

    private func displayLockConfirmation(entity: HAEntity, completion: @escaping () -> Void) {
        guard let state = Domain.State(rawValue: entity.state) else { return }
        var title = ""
        switch state {
        case .locked, .locking:
            title = L10n.Carplay.Unlock.Confirmation.title(entity.attributes.friendlyName ?? entity.entityId)
        default:
            title = L10n.Carplay.Lock.Confirmation.title(entity.attributes.friendlyName ?? entity.entityId)
        }

        let alert = CPAlertTemplate(titleVariants: [title], actions: [
            .init(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
            .init(title: L10n.Alerts.Confirm.confirm, style: .destructive, handler: { [weak self] _ in
                completion()
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            })
        ])

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }

    private func getPageButtons(endIndex: Int, currentPage: Int, totalCount: Int) -> [CPBarButton] {
        var barButtons: [CPBarButton] = []

        guard let forwardImage = UIImage(systemName: "arrow.forward"),
              let backwardImage = UIImage(systemName: "arrow.backward") else { return [] }

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

    private func changePage(to: GridPage) {
        switch to {
        case .Next:
            currentPage += 1
        case .Previous:
            currentPage -= 1
        }
        updateListItems()
    }
}
