import CarPlay
@testable import HomeAssistant
@testable import Shared
import XCTest

/// CarPlay caps how many rows a list may hold, so longer lists are split into pages: either with
/// arrow rows inside the list, or with arrow buttons in the navigation bar.
final class CarPlayPaginatedListTemplateTests: XCTestCase {
    private var maximumItems: Int {
        Int(CPListTemplate.maximumItemCount)
    }

    private func rows(_ count: Int) -> [CPListItem] {
        (0 ..< count).map { CPListItem(text: "Row \($0)", detailText: nil) }
    }

    private func drain() {
        CarPlayTestHelpers.drainMainQueue(self)
    }

    private func texts(of sut: CarPlayPaginatedListTemplate) throws -> [String?] {
        let template = try XCTUnwrap(sut.listTemplate)
        return CarPlayTestHelpers.listItems(of: template).map(\.text)
    }

    func testAShortListIsASinglePage() throws {
        let sut = CarPlayPaginatedListTemplate(title: "Short", items: [], paginationStyle: .inline)
        sut.updateItems(items: rows(2))
        drain()

        XCTAssertEqual(try texts(of: sut), ["Row 0", "Row 1"])
        XCTAssertNil(sut.gridTemplate)
        XCTAssertEqual(sut.listTemplate?.trailingNavigationBarButtons.count, 0)
    }

    /// Inline pagination keeps two slots for the arrow rows, which have no text.
    func testInlinePagesNavigateWithArrowRows() throws {
        try XCTSkipIf(maximumItems < 4, "Needs room for rows besides the arrows")
        let perPage = maximumItems - 2
        let sut = CarPlayPaginatedListTemplate(title: "Long", items: [], paginationStyle: .inline)
        sut.updateItems(items: rows(perPage + 3))
        drain()

        var page = try texts(of: sut)
        XCTAssertEqual(page.count, perPage + 1)
        XCTAssertEqual(page.first, "Row 0")
        XCTAssertNil(page.last ?? nil, "The last row is the next-page arrow")

        let template = try XCTUnwrap(sut.listTemplate)
        try CarPlayTestHelpers.tap(XCTUnwrap(CarPlayTestHelpers.listItems(of: template).last))
        page = try texts(of: sut)
        XCTAssertEqual(page.count, 4, "Previous arrow plus the three remaining rows")
        XCTAssertNil(page.first ?? nil, "The first row is the previous-page arrow")
        XCTAssertEqual(page.last, "Row \(perPage + 2)")

        try CarPlayTestHelpers.tap(XCTUnwrap(CarPlayTestHelpers.listItems(of: template).first))
        XCTAssertEqual(try texts(of: sut).first, "Row 0")
    }

    func testNavigationPagesUseTheBarButtons() throws {
        let sut = CarPlayPaginatedListTemplate(title: "Long", items: [])
        sut.updateItems(items: rows(maximumItems + 2))
        drain()

        let template = try XCTUnwrap(sut.listTemplate)
        XCTAssertEqual(try texts(of: sut).count, maximumItems)
        XCTAssertEqual(template.trailingNavigationBarButtons.count, 2)
        let forward = try XCTUnwrap(template.trailingNavigationBarButtons.first)
        XCTAssertNil(template.trailingNavigationBarButtons.last?.handler, "No previous page yet")

        forward.handler?(forward)
        XCTAssertEqual(try texts(of: sut), ["Row \(maximumItems)", "Row \(maximumItems + 1)"])
        XCTAssertNil(template.trailingNavigationBarButtons.first?.handler, "No next page any more")

        let backward = try XCTUnwrap(template.trailingNavigationBarButtons.last)
        backward.handler?(backward)
        XCTAssertEqual(try texts(of: sut).first, "Row 0")
    }

    /// Shrinking the list while on a later page lands on the last page that still exists.
    func testShrinkingTheListKeepsAValidPage() throws {
        let sut = CarPlayPaginatedListTemplate(title: "Long", items: [])
        sut.updateItems(items: rows(maximumItems + 2))
        drain()
        let template = try XCTUnwrap(sut.listTemplate)
        let forward = try XCTUnwrap(template.trailingNavigationBarButtons.first)
        forward.handler?(forward)

        sut.updateItems(items: rows(1))
        drain()

        XCTAssertEqual(try texts(of: sut), ["Row 0"])
    }

    func testFooterRowsFollowThePage() throws {
        let footer = CPListItem(text: "Footer", detailText: nil)
        let sut = CarPlayPaginatedListTemplate(title: "Footer", items: [])
        sut.updateItems(items: rows(2), footerItems: [footer])
        drain()

        let template = try XCTUnwrap(sut.listTemplate)
        XCTAssertEqual(template.sections.count, 2)
        XCTAssertTrue(template.sections.last?.items.first === footer)
    }

    /// Re-applying the very same rows leaves the sections alone, which keeps the rotary focus.
    func testReapplyingTheSameRowsKeepsTheSections() throws {
        let items = rows(3)
        let sut = CarPlayPaginatedListTemplate(title: "Same", templateItems: [])
        sut.updateItems(items: items as [any CPListTemplateItem])
        drain()
        let template = try XCTUnwrap(sut.listTemplate)
        let section = try XCTUnwrap(template.sections.first)

        sut.updateTemplate()

        XCTAssertTrue(template.sections.first === section)
        XCTAssertEqual(try texts(of: sut), ["Row 0", "Row 1", "Row 2"])
    }

    /// Lists of mixed row kinds (iOS 26 image rows) can't hold inline arrows, so they fall back to
    /// the bar buttons even when inline pagination was asked for.
    func testTemplateItemListsUseTheBarButtons() throws {
        let sut = CarPlayPaginatedListTemplate(title: "Mixed", templateItems: [], paginationStyle: .inline)
        sut.updateItems(items: rows(maximumItems + 1) as [any CPListTemplateItem])
        drain()

        let template = try XCTUnwrap(sut.listTemplate)
        XCTAssertEqual(try texts(of: sut).count, maximumItems)
        XCTAssertEqual(template.trailingNavigationBarButtons.count, 2)
    }

    func testGridButtonsArePaged() throws {
        let image = try XCTUnwrap(UIImage(systemName: "star"))
        let buttons = (0 ..< 20).map { CPGridButton(titleVariants: ["Button \($0)"], image: image, handler: nil) }
        let sut = CarPlayPaginatedListTemplate(title: "Grid", gridButtons: [], paginationStyle: .inline)

        sut.updateGridButtons(gridButtons: buttons)
        drain()

        if #available(iOS 26.0, *) {
            let template = try XCTUnwrap(sut.listTemplate)
            let perPage = Int(CPListTemplate.maximumHeaderGridButtonCount)
            XCTAssertEqual(template.headerGridButtons?.count, min(20, perPage))
        } else {
            let template = try XCTUnwrap(sut.gridTemplate)
            XCTAssertEqual(template.gridButtons.count, min(20, Int(CPGridTemplateMaximumItems)))
        }
    }
}
