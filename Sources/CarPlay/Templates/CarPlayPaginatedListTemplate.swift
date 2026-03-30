import CarPlay
import Foundation
import SFSafeSymbols
import Shared

final class CarPlayPaginatedListTemplate {
    enum PaginationStyle {
        case inline
        case navigation
    }

    enum PageDirection {
        case next
        case previous
    }

    private enum Content {
        case list([CPListItem])
        case grid([CPGridButton])
    }

    private var content: Content
    private var currentPage: Int
    private let title: String
    private let paginationStyle: PaginationStyle

    private(set) var template: CPTemplate
    var listTemplate: CPListTemplate? { template as? CPListTemplate }
    var gridTemplate: CPGridTemplate? { template as? CPGridTemplate }

    init(title: String, items: [CPListItem], paginationStyle: PaginationStyle = .navigation) {
        self.title = title
        self.content = .list(items)
        self.paginationStyle = paginationStyle
        self.currentPage = 0
        self.template = CPListTemplate(title: title, sections: [])
    }

    init(title: String, gridButtons: [CPGridButton], paginationStyle: PaginationStyle = .navigation) {
        self.title = title
        self.content = .grid(gridButtons)
        self.paginationStyle = paginationStyle == .inline ? .navigation : paginationStyle
        self.currentPage = 0
        if #available(iOS 26.0, *) {
            let template = CPListTemplate(title: title, sections: [])
            template.headerGridButtons = []
            self.template = template
        } else {
            self.template = CPGridTemplate(title: title, gridButtons: [])
        }
    }

    func updateItems(items: [CPListItem]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard case .list = content else {
                assertionFailure("Attempted to update list items on a grid-backed CarPlayPaginatedListTemplate")
                return
            }
            content = .list(items)
            updateTemplate()
        }
    }

    func updateGridButtons(gridButtons: [CPGridButton]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard case .grid = content else {
                assertionFailure("Attempted to update grid buttons on a list-backed CarPlayPaginatedListTemplate")
                return
            }
            content = .grid(gridButtons)
            updateTemplate()
        }
    }

    func updateTemplate() {
        let totalItems = itemsCount
        let itemsPerPage = maximumItemsPerPage
        let maxPage = totalItems > 0 ? (totalItems - 1) / itemsPerPage : 0
        currentPage = min(currentPage, maxPage)

        let startIndex = min(currentPage * itemsPerPage, totalItems)
        let endIndex = min(startIndex + itemsPerPage, totalItems)
        let shouldUseInlinePagination = paginationStyle == .inline && isListContent

        if shouldUseInlinePagination {
            var pageItems = Array(listItems[startIndex ..< endIndex])
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
            listTemplate?.updateSections([CPListSection(items: pageItems)])
            updateTrailingNavigationButtons([])
            return
        }

        updateTrailingNavigationButtons(getPageButtons(
            endIndex: endIndex,
            currentPage: currentPage,
            totalCount: totalItems
        ))

        switch content {
        case .list:
            let section = CPListSection(items: Array(listItems[startIndex ..< endIndex]))
            listTemplate?.updateSections([section])
        case .grid:
            if #available(iOS 26.0, *), let listTemplate {
                listTemplate.updateSections([])
                listTemplate.headerGridButtons = Array(gridButtons[startIndex ..< endIndex])
            } else {
                gridTemplate?.updateGridButtons(Array(gridButtons[startIndex ..< endIndex]))
            }
        }
    }

    private var isListContent: Bool {
        if case .list = content {
            true
        } else {
            false
        }
    }

    private var listItems: [CPListItem] {
        if case let .list(items) = content {
            items
        } else {
            []
        }
    }

    private var gridButtons: [CPGridButton] {
        if case let .grid(buttons) = content {
            buttons
        } else {
            []
        }
    }

    private var itemsCount: Int {
        switch content {
        case let .list(items):
            items.count
        case let .grid(buttons):
            buttons.count
        }
    }

    private var maximumItemsPerPage: Int {
        switch content {
        case let .list(items):
            var itemsPerPage = Int(CPListTemplate.maximumItemCount)
            if paginationStyle == .inline, items.count > itemsPerPage {
                itemsPerPage -= 2
            }
            return itemsPerPage
        case .grid:
            if #available(iOS 26.0, *), listTemplate != nil {
                return Int(CPListTemplate.maximumHeaderGridButtonCount)
            } else {
                return Int(CPGridTemplateMaximumItems)
            }
        }
    }

    private func updateTrailingNavigationButtons(_ buttons: [CPBarButton]) {
        if let listTemplate {
            listTemplate.trailingNavigationBarButtons = buttons
        } else {
            gridTemplate?.trailingNavigationBarButtons = buttons
        }
    }

    private func getPageButtons(endIndex: Int, currentPage: Int, totalCount: Int) -> [CPBarButton] {
        var barButtons: [CPBarButton] = []

        let forwardImage = UIImage(systemSymbol: .arrowForward)
        let backwardImage = UIImage(systemSymbol: .arrowBackward)

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

    private func changePage(to: PageDirection) {
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
