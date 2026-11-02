import CarPlay
@testable import HomeAssistant
import Testing

/// Paging through more rows (or grid buttons) than CarPlay shows at once: inline arrow rows, or
/// forward/back bar buttons, plus the footer section and the grid variant.
@MainActor
struct CarPlayPaginatedListTemplateTests {
    private var pageSize: Int { Int(CPListTemplate.maximumItemCount) }

    private func items(_ count: Int) -> [CPListItem] {
        (0 ..< count).map { CPListItem(text: "Item \($0)", detailText: nil) }
    }

    private func rows(_ sut: CarPlayPaginatedListTemplate) -> [CPListItem] {
        CarPlayTestRows.listItems(sut.listTemplate)
    }

    private func applied(_ sut: CarPlayPaginatedListTemplate, _ condition: @escaping () -> Bool) async -> Bool {
        await carPlayEventually(condition)
    }

    @Test func inlinePaginationAddsArrowRowsBetweenPages() async throws {
        let sut = CarPlayPaginatedListTemplate(title: "List", items: [], paginationStyle: .inline)
        sut.updateItems(items: items(pageSize * 2))
        let firstPage = await applied(sut) { !rows(sut).isEmpty }
        #expect(firstPage)

        let pageOne = rows(sut)
        #expect(pageOne.count == pageSize - 1, "a page of items plus the next arrow")
        #expect(pageOne.first?.text == "Item 0")
        #expect(pageOne.last?.text == nil)
        #expect(sut.listTemplate?.trailingNavigationBarButtons.isEmpty == true)

        CarPlayTestRows.tap(pageOne.last)
        let pageTwo = rows(sut)
        #expect(pageTwo.first?.text == nil, "the previous arrow leads the second page")
        #expect(pageTwo.dropFirst().first?.text == "Item \(pageSize - 2)")

        CarPlayTestRows.tap(pageTwo.first)
        #expect(rows(sut).first?.text == "Item 0")
    }

    @Test func navigationPaginationUsesBarButtons() async {
        let sut = CarPlayPaginatedListTemplate(title: "List", items: [])
        sut.updateItems(items: items(pageSize + 1), footerItems: [CPListItem(text: "Footer", detailText: nil)])
        let applied = await applied(sut) { !rows(sut).isEmpty }
        #expect(applied)

        #expect(rows(sut).last?.text == "Footer")
        #expect(sut.listTemplate?.sections.count == 2)
        #expect(sut.listTemplate?.trailingNavigationBarButtons.count == 2)

        // CarPlay runs the bar buttons' handlers; `CPBarButton` doesn't expose them, so page directly.
        sut.changePage(to: .next)
        #expect(rows(sut).first?.text == "Item \(pageSize - 1)")
        #expect(sut.listTemplate?.trailingNavigationBarButtons.count == 2)

        sut.changePage(to: .previous)
        #expect(rows(sut).first?.text == "Item 0")
        sut.changePage(to: .previous)
        #expect(rows(sut).first?.text == "Item 0", "there is nothing before the first page")
    }

    @Test func reapplyingTheSameRowsKeepsTheSections() async throws {
        let list = items(2)
        let sut = CarPlayPaginatedListTemplate(title: "List", templateItems: list)
        sut.updateItems(items: list as [any CPListTemplateItem])
        let applied = await applied(sut) { rows(sut).count == 2 }
        #expect(applied)
        let sections = sut.listTemplate?.sections.first

        sut.updateTemplate()

        #expect(sut.listTemplate?.sections.first === sections)
        #expect(sut.gridTemplate == nil)
    }

    @Test func gridButtonsBecomeHeaderButtonsAndPage() async throws {
        guard #available(iOS 26.0, *) else { return }
        let sut = CarPlayPaginatedListTemplate(title: "Grid", gridButtons: [], paginationStyle: .inline)
        let maximum = Int(CPListTemplate.maximumHeaderGridButtonCount)
        let buttons = (0 ... maximum).map { CPGridButton(titleVariants: ["\($0)"], image: UIImage(), handler: nil) }

        sut.updateGridButtons(gridButtons: buttons)
        let applied = await applied(sut) { sut.listTemplate?.headerGridButtons?.isEmpty == false }
        #expect(applied)

        #expect(sut.listTemplate?.headerGridButtons?.count == maximum)
        sut.changePage(to: .next)
        #expect(sut.listTemplate?.headerGridButtons?.count == 1)
    }
}
