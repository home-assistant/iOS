import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

// Exercises the Focus names the user creates in settings: the names are the state the `focus_name`
// sensor reports, so they have to be trimmed, unique, and stop being reported once deleted.
@MainActor
struct FocusSettingsViewModelTests {
    private func makeViewModel() throws -> FocusSettingsViewModel {
        try Current.database().write { db in
            _ = try FocusName.deleteAll(db)
        }
        Current.focusFilter = FocusFilterWrapper()
        let viewModel = FocusSettingsViewModel()
        viewModel.load()
        return viewModel
    }

    @Test func addTrimsWhitespaceAndSorts() throws {
        let viewModel = try makeViewModel()

        viewModel.add(name: "  Work  ")
        viewModel.add(name: "Sleep")

        #expect(viewModel.focusNames.map(\.name) == ["Sleep", "Work"])
    }

    @Test func addIgnoresBlankNames() throws {
        let viewModel = try makeViewModel()

        viewModel.add(name: "   ")

        #expect(viewModel.focusNames.isEmpty)
        #expect(viewModel.canAdd(name: "   ") == false)
    }

    @Test func addRejectsDuplicatesRegardlessOfCase() throws {
        let viewModel = try makeViewModel()

        viewModel.add(name: "Work")
        viewModel.add(name: "work")

        #expect(viewModel.focusNames.map(\.name) == ["Work"])
        #expect(viewModel.canAdd(name: "WORK") == false)
        #expect(viewModel.canAdd(name: "Sleep"))
    }

    @Test func deleteStopsReportingTheDeletedName() throws {
        let viewModel = try makeViewModel()
        var reportedName: String? = "Work"
        Current.focusFilter.activeFocusName = { reportedName }
        Current.focusFilter.forgetFocusName = { name in
            if reportedName == name { reportedName = nil }
        }

        viewModel.add(name: "Work")
        viewModel.add(name: "Sleep")
        let work = try #require(viewModel.focusNames.first { $0.name == "Work" })
        viewModel.delete(work)

        #expect(viewModel.focusNames.map(\.name) == ["Sleep"])
        #expect(reportedName == nil)
        #expect(viewModel.activeFocusName == nil)
    }

    @Test func deleteKeepsAnUnrelatedReportedName() throws {
        let viewModel = try makeViewModel()
        var reportedName: String? = "Sleep"
        Current.focusFilter.activeFocusName = { reportedName }
        Current.focusFilter.forgetFocusName = { name in
            if reportedName == name { reportedName = nil }
        }

        viewModel.add(name: "Work")
        let work = try #require(viewModel.focusNames.first { $0.name == "Work" })
        viewModel.delete(work)

        #expect(reportedName == "Sleep")
    }
}
