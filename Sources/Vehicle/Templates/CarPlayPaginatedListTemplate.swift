import CarPlay
import Foundation
import Shared

final class CarPlayPaginatedListTemplate {
    enum PaginationStyle {
        case inline
        case navigation
    }

    enum GridPage {
        case next
        case previous
    }

    private var items: [CPListItem]
    private var currentPage: Int
    private let title: String
    private let paginationStyle: PaginationStyle

    private(set) var template: CPListTemplate

    init(title: String, items: [CPListItem], paginationStyle: PaginationStyle = .navigation) {
        self.title = title
        self.items = items
        self.paginationStyle = paginationStyle
        self.currentPage = 0
        self.template = CPListTemplate(title: title, sections: [])
    }

    func updateItems(items: [CPListItem]) {
        self.items = items
        updateTemplate()
    }

    func updateTemplate() {
        let totalItems = items.count
        var itemsPerPage = CPListTemplate.maximumItemCount

        if paginationStyle == .inline, items.count > itemsPerPage {
            itemsPerPage = CPListTemplate.maximumItemCount - 2
        }

        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, totalItems)
        var pageItems = Array(items[startIndex ..< endIndex])

        if paginationStyle == .inline {
            if currentPage > 0 {
                let previousItem = CPListItem(text: nil, detailText: nil)
                previousItem.setImage(MaterialDesignIcons.arrowLeftIcon.carPlayIcon())
                previousItem.handler = { [weak self] _, completion in
                    self?.changePage(to: .previous)
                    completion()
                }
                pageItems.insert(previousItem, at: 0)
            }
            if endIndex < totalItems {
                let nextItem = CPListItem(text: nil, detailText: nil)
                nextItem.setImage(MaterialDesignIcons.arrowRightIcon.carPlayIcon())
                nextItem.handler = { [weak self] _, completion in
                    self?.changePage(to: .next)
                    completion()
                }
                pageItems.insert(nextItem, at: pageItems.endIndex)
            }
        } else {
            template.trailingNavigationBarButtons = getPageButtons(
                endIndex: endIndex,
                currentPage: currentPage,
                totalCount: totalItems
            )
        }
        let section = CPListSection(items: pageItems)
        template.updateSections([section])
    }

    private func getPageButtons(endIndex: Int, currentPage: Int, totalCount: Int) -> [CPBarButton] {
        var barButtons: [CPBarButton] = []

        guard let forwardImage = UIImage(systemName: "arrow.forward"),
              let backwardImage = UIImage(systemName: "arrow.backward") else { return [] }

        if endIndex < totalCount {
            barButtons.append(CPBarButton(
                image: forwardImage,
                handler: { [weak self] _ in
                    self?.changePage(to: .next)
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
                handler: { [weak self] _ in
                    self?.changePage(to: .previous)
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
        var newCurrentPage = currentPage
        switch to {
        case .next:
            newCurrentPage += 1
        case .previous:
            newCurrentPage -= 1
        }
        guard newCurrentPage >= 0 else { return }
        currentPage = newCurrentPage
        updateTemplate()
    }
}
