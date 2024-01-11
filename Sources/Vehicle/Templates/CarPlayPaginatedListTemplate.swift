import CarPlay
import Foundation
import Shared

final class CarPlayPaginatedListTemplate {
    enum GridPage {
        case next
        case previous
    }

    private var items: [CPListItem]
    private var currentPage: Int
    private let title: String

    private let itemsPerPage: Int = CPListTemplate.maximumItemCount
    private(set) var template: CPListTemplate

    init(title: String, items: [CPListItem]) {
        self.title = title
        self.items = items
        self.currentPage = 0
        self.template = CPListTemplate(title: title, sections: [])
    }

    func updateItems(items: [CPListItem], refreshUI: Bool = false) {
        self.items = items
        if refreshUI {
            updateTemplate()
        }
    }

    func updateTemplate() {
        let totalItems = items.count
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, totalItems)
        let pageItems = Array(items[startIndex ..< endIndex])

        let section = CPListSection(items: pageItems)
        template.updateSections([section])
        template.trailingNavigationBarButtons = getPageButtons(
            endIndex: endIndex,
            currentPage: currentPage,
            totalCount: totalItems
        )
    }

    private func getPageButtons(endIndex: Int, currentPage: Int, totalCount: Int) -> [CPBarButton] {
        var barButtons: [CPBarButton] = []

        guard let forwardImage = UIImage(systemName: "arrow.forward"),
              let backwardImage = UIImage(systemName: "arrow.backward") else { return [] }

        if endIndex < totalCount {
            barButtons.append(CPBarButton(
                image: forwardImage,
                handler: { _ in
                    self.changePage(to: .next)
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
                    self.changePage(to: .previous)
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
