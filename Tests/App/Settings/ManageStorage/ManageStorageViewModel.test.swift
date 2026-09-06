import Foundation
@testable import HomeAssistant
import Testing

@MainActor
struct ManageStorageViewModelTests {
    private let paths = ManageStoragePaths.rooted(at: URL(fileURLWithPath: "/tmp/manage-storage-view-model"))

    private func makeViewModel(
        byteCounts: [ManageStorageItemID: Int64] = [:],
        isCatalyst: Bool = false,
        hasCompletedLegacyStoreMigration: Bool = true,
        cleaner: ManageStorageCleanerMock = ManageStorageCleanerMock()
    ) -> (ManageStorageViewModel, ManageStorageMeasurerMock, ManageStorageCleanerMock) {
        let measurer = ManageStorageMeasurerMock(byteCounts: byteCounts)
        let viewModel = ManageStorageViewModel(
            paths: paths,
            isCatalyst: isCatalyst,
            hasCompletedLegacyStoreMigration: hasCompletedLegacyStoreMigration,
            measurer: measurer,
            cleaner: cleaner
        )
        return (viewModel, measurer, cleaner)
    }

    @Test func theScreenListsEverythingBeforeItHasMeasuredAnything() {
        let (viewModel, measurer, _) = makeViewModel()

        #expect(viewModel.items.count == ManageStorageItemID.allCases.count)
        #expect(viewModel.items.allSatisfy { $0.byteCount == 0 })
        #expect(measurer.measured.isEmpty)
        #expect(!viewModel.isLoading)
    }

    @Test func loadingMeasuresEveryRowOnce() async {
        let (viewModel, measurer, _) = makeViewModel(byteCounts: [.logFiles: 500, .widgetCache: 250])

        await viewModel.load()

        #expect(Set(measurer.measured) == Set(ManageStorageItemID.allCases))
        #expect(measurer.measured.count == ManageStorageItemID.allCases.count)
        #expect(viewModel.items.first { $0.id == .logFiles }?.byteCount == 500)
        #expect(viewModel.items.first { $0.id == .widgetCache }?.byteCount == 250)
        #expect(!viewModel.isLoading)
    }

    @Test func theTotalLeavesOutRowsStoredInsideTheDatabase() async {
        let (viewModel, _, _) = makeViewModel(byteCounts: [
            .appDatabase: 1000,
            .cachedEntities: 900,
            .logFiles: 100,
        ])

        await viewModel.load()

        #expect(viewModel.totalByteCount == 1100)
    }

    @Test func onlyDeletableRowsCountAsReclaimable() async {
        let (viewModel, _, _) = makeViewModel(byteCounts: [
            .appDatabase: 1000,
            .logFiles: 100,
            .widgetCache: 50,
        ])

        await viewModel.load()

        #expect(viewModel.reclaimableByteCount == 150)
        #expect(viewModel.protectedItemCount == 3)
    }

    @Test func theLegacyStoreCountsAsProtectedWhileItsImportIsPending() {
        let (viewModel, _, _) = makeViewModel(hasCompletedLegacyStoreMigration: false)

        #expect(viewModel.protectedItemCount == 4)
    }

    @Test func rowsAreGroupedIntoTheCategoriesTheyBelongTo() async {
        let (viewModel, _, _) = makeViewModel(byteCounts: [.frontendAssetCache: 900, .logFiles: 100])

        await viewModel.load()

        #expect(viewModel.sections.first?.category == .webContent)
        #expect(Set(viewModel.sections.map(\.category)) == Set(ManageStorageCategory.allCases))
        for section in viewModel.sections {
            #expect(section.items.allSatisfy { $0.category == section.category })
        }
    }

    @Test func filteringNarrowsBothRowsAndSections() async {
        let (viewModel, _, _) = makeViewModel()
        await viewModel.load()

        viewModel.filter.category = .temporary

        #expect(viewModel.visibleItems.map(\.id) == [.temporaryFiles])
        #expect(viewModel.sections.map(\.category) == [.temporary])
    }

    @Test func sortingReordersTheVisibleRows() async {
        let (viewModel, _, _) = makeViewModel(byteCounts: [.logFiles: 100, .clientEventLog: 900])
        await viewModel.load()
        viewModel.filter.category = .logs

        viewModel.sortOrder = .largestFirst
        let largestFirst = viewModel.visibleItems.map(\.id)
        viewModel.sortOrder = .smallestFirst
        let smallestFirst = viewModel.visibleItems.map(\.id)

        #expect(largestFirst.first == .clientEventLog)
        #expect(smallestFirst.last == .clientEventLog)
    }

    @Test func theFilterMenuOnlyOffersCategoriesThatHaveRows() {
        let (viewModel, _, _) = makeViewModel()

        #expect(viewModel.availableCategories == ManageStorageCategory.allCases)
    }

    @Test func askingToDeleteADeletableRowOpensTheConfirmation() async throws {
        let (viewModel, _, _) = makeViewModel(byteCounts: [.logFiles: 100])
        await viewModel.load()
        let logs = try #require(viewModel.items.first { $0.id == .logFiles })

        viewModel.confirmCleaning(of: logs)

        #expect(viewModel.itemPendingCleaning?.id == .logFiles)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func askingToDeleteAProtectedRowExplainsWhyItCannotBeDeleted() async throws {
        let (viewModel, _, _) = makeViewModel(byteCounts: [.appDatabase: 100])
        await viewModel.load()
        let database = try #require(viewModel.items.first { $0.id == .appDatabase })

        viewModel.confirmCleaning(of: database)

        #expect(viewModel.itemPendingCleaning == nil)
        #expect(viewModel.errorMessage == ManageStorageProtectionReason.essentialAppData.explanation)
    }

    @Test func cleaningARowEmptiesItAndMeasuresItAgain() async throws {
        let measurer = ManageStorageMeasurerMock(byteCounts: [.logFiles: 500])
        let cleaner = ManageStorageCleanerMock()
        let viewModel = ManageStorageViewModel(
            paths: paths,
            isCatalyst: false,
            hasCompletedLegacyStoreMigration: true,
            measurer: measurer,
            cleaner: cleaner
        )
        await viewModel.load()
        let logs = try #require(viewModel.items.first { $0.id == .logFiles })
        measurer.byteCounts[.logFiles] = 0

        await viewModel.clean(logs)

        #expect(cleaner.cleaned == [.logFiles])
        #expect(viewModel.items.first { $0.id == .logFiles }?.byteCount == 0)
        #expect(viewModel.cleaningItemID == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func cleaningRefusesAProtectedRowEvenWhenAskedDirectly() async throws {
        let (viewModel, _, cleaner) = makeViewModel(byteCounts: [.appDatabase: 100])
        await viewModel.load()
        let database = try #require(viewModel.items.first { $0.id == .appDatabase })

        await viewModel.clean(database)

        #expect(cleaner.cleaned.isEmpty)
        #expect(viewModel.items.first { $0.id == .appDatabase }?.byteCount == 100)
        #expect(viewModel.errorMessage == ManageStorageProtectionReason.essentialAppData.explanation)
    }

    @Test func aFailedCleanIsReportedAndTheRowIsMeasuredAgain() async throws {
        let cleaner = ManageStorageCleanerMock()
        cleaner.errorToThrow = ManageStorageCleanerMock.Failure()
        let (viewModel, _, _) = makeViewModel(byteCounts: [.logFiles: 500], cleaner: cleaner)
        await viewModel.load()
        let logs = try #require(viewModel.items.first { $0.id == .logFiles })

        await viewModel.clean(logs)

        #expect(viewModel.errorMessage == ManageStorageCleanerMock.Failure().localizedDescription)
        #expect(viewModel.items.first { $0.id == .logFiles }?.byteCount == 500)
        #expect(viewModel.cleaningItemID == nil)
    }

    @Test func measuringAgainAfterACleanSurvivesAConcurrentReload() async throws {
        let measurer = ManageStorageMeasurerMock(byteCounts: [.logFiles: 500, .widgetCache: 250])
        let cleaner = ManageStorageCleanerMock()
        let viewModel = ManageStorageViewModel(
            paths: paths,
            isCatalyst: false,
            hasCompletedLegacyStoreMigration: true,
            measurer: measurer,
            cleaner: cleaner
        )
        await viewModel.load()
        let logs = try #require(viewModel.items.first { $0.id == .logFiles })
        measurer.byteCounts[.logFiles] = 0

        async let clean: Void = viewModel.clean(logs)
        async let reload: Void = viewModel.load()
        _ = await (clean, reload)

        #expect(viewModel.items.count == ManageStorageItemID.allCases.count)
        #expect(viewModel.items.first { $0.id == .widgetCache }?.byteCount == 250)
    }
}
