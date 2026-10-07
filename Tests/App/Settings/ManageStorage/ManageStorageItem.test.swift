import Foundation
@testable import HomeAssistant
import Testing

struct ManageStorageItemTests {
    private func makeItem(
        id: ManageStorageItemID = .logFiles,
        protection: ManageStorageProtection = .deletable,
        byteCount: Int64 = 0
    ) -> ManageStorageItem {
        ManageStorageItem(
            id: id,
            category: .logs,
            protection: protection,
            source: .files([]),
            byteCount: byteCount
        )
    }

    @Test func itemBorrowsItsCopyFromItsIdentifier() {
        let subject = makeItem()

        #expect(subject.title == ManageStorageItemID.logFiles.title)
        #expect(subject.explanation == ManageStorageItemID.logFiles.explanation)
        #expect(subject.countsTowardTotal)
    }

    @Test func sizeIsFormattedAsAFileSize() {
        #expect(ManageStorageItem.formatted(byteCount: 0) == Int64(0).formatted(.byteCount(style: .file)))
        #expect(makeItem(byteCount: 1_048_576).formattedSize == Int64(1_048_576).formatted(.byteCount(style: .file)))
    }

    @Test func onlyADeletableRowHoldingSomethingCanBeCleaned() {
        #expect(makeItem(protection: .deletable, byteCount: 10).isCleanable)
        #expect(!makeItem(protection: .deletable, byteCount: 0).isCleanable)
        #expect(!makeItem(protection: .protected(.essentialAppData), byteCount: 10).isCleanable)
        #expect(!makeItem(protection: .protected(.essentialAppData), byteCount: 10).isDeletable)
    }

    @Test func anEmptySearchTermMatchesEverything() {
        #expect(makeItem().matches(searchTerm: ""))
        #expect(makeItem().matches(searchTerm: "   \n "))
    }

    @Test func searchMatchesTitleExplanationAndCategory() {
        let subject = makeItem()

        #expect(subject.matches(searchTerm: String(subject.title.prefix(4))))
        #expect(subject.matches(searchTerm: subject.title.uppercased()))
        #expect(subject.matches(searchTerm: String(subject.explanation.prefix(6))))
        #expect(subject.matches(searchTerm: subject.category.title))
        #expect(!subject.matches(searchTerm: "zzzzz-no-such-row"))
    }
}
