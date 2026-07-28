@testable import HomeAssistant
@testable import Shared
import Testing

struct SensorListViewModelSearchTests {
    @Test func sensorsAreSortedAlphabeticallyRegardlessOfEnabledState() {
        let unnamed = WebhookSensor()
        unnamed.UniqueID = "unnamed"

        let sorted = SensorListViewModel.sortedAlphabetically([
            WebhookSensor(name: "Storage", uniqueID: "storage"),
            WebhookSensor(name: "activity", uniqueID: "activity"),
            WebhookSensor(name: "Battery Level", uniqueID: "battery_level"),
            unnamed,
        ])

        #expect(sorted.map(\.UniqueID) == ["unnamed", "activity", "battery_level", "storage"])
    }

    @Test func sortingIsStableForSensorsSharingAName() {
        let sorted = SensorListViewModel.sortedAlphabetically([
            WebhookSensor(name: "Battery", uniqueID: "battery_b"),
            WebhookSensor(name: "Battery", uniqueID: "battery_a"),
        ])

        #expect(sorted.map(\.UniqueID) == ["battery_a", "battery_b"])
    }

    @MainActor
    @Test func filteredSensorsMatchTheSearchTermCaseAndDiacriticInsensitively() {
        let viewModel = SensorListViewModel()
        viewModel.sensors = [
            WebhookSensor(name: "Battery Level", uniqueID: "battery_level"),
            WebhookSensor(name: "Battery State", uniqueID: "battery_state"),
            WebhookSensor(name: "Storage", uniqueID: "storage"),
        ]

        viewModel.searchTerm = "battery"
        #expect(viewModel.filteredSensors.map(\.UniqueID) == ["battery_level", "battery_state"])
        #expect(viewModel.isSearching)

        viewModel.searchTerm = "  "
        #expect(viewModel.filteredSensors.count == 3)
        #expect(!viewModel.isSearching)

        viewModel.searchTerm = "nothing here"
        #expect(viewModel.filteredSensors.isEmpty)
    }
}
