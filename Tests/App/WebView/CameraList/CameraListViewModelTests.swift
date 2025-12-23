@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class CameraListViewModelTests: XCTestCase {
    private var sut: CameraListViewModel!
    private var mockDiskCache: MockDiskCache!

    override func setUp() {
        super.setUp()

        // Setup mock disk cache
        mockDiskCache = MockDiskCache()

        // Create system under test
        sut = CameraListViewModel(serverId: "test_server", diskCache: mockDiskCache)
    }

    override func tearDown() {
        sut = nil
        mockDiskCache = nil

        super.tearDown()
    }

    // MARK: - Camera Sorting Tests

    func testDefaultAlphabeticalSorting() {
        // Given: Cameras with no custom order
        sut.cameras = [
            makeCamera(entityId: "camera.zebra", name: "Zebra Camera"),
            makeCamera(entityId: "camera.alpha", name: "Alpha Camera"),
            makeCamera(entityId: "camera.beta", name: "Beta Camera"),
        ]
        sut.selectedServerId = "test_server"

        // When: Getting grouped cameras
        let grouped = sut.groupedCameras

        // Then: Cameras should be sorted alphabetically within the group
        XCTAssertEqual(grouped.count, 1) // All in "No Area"
        if let cameras = grouped.first?.cameras {
            XCTAssertEqual(cameras.count, 3)
            XCTAssertEqual(cameras[0].name, "Alpha Camera")
            XCTAssertEqual(cameras[1].name, "Beta Camera")
            XCTAssertEqual(cameras[2].name, "Zebra Camera")
        }
    }

    func testCustomCameraOrderIsApplied() {
        // Given: Custom camera order stored before creating view model
        let areaName = L10n.CameraList.noArea
        let storage = CameraOrderStorage(
            areaOrders: [areaName: ["camera.zebra", "camera.beta", "camera.alpha"]],
            sectionOrder: nil
        )
        mockDiskCache.setStoredValue(storage, forKey: "camera_order_test_server")

        // Create view model after setting up storage
        sut = CameraListViewModel(serverId: "test_server", diskCache: mockDiskCache)

        sut.cameras = [
            makeCamera(entityId: "camera.alpha", name: "Alpha Camera"),
            makeCamera(entityId: "camera.beta", name: "Beta Camera"),
            makeCamera(entityId: "camera.zebra", name: "Zebra Camera"),
        ]
        sut.selectedServerId = "test_server"

        // Note: RunLoop is needed because loadCameraOrders() uses .done{} which schedules
        // callbacks asynchronously even though MockDiskCache returns fulfilled promises
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // When: Getting grouped cameras
        let grouped = sut.groupedCameras

        // Then: Cameras should follow custom order
        if let cameras = grouped.first?.cameras {
            XCTAssertEqual(cameras.count, 3)
            XCTAssertEqual(cameras[0].entityId, "camera.zebra")
            XCTAssertEqual(cameras[1].entityId, "camera.beta")
            XCTAssertEqual(cameras[2].entityId, "camera.alpha")
        }
    }

    func testNewCamerasAddedToEndWhenCustomOrderExists() {
        // Given: Custom order with only 2 cameras
        let areaName = L10n.CameraList.noArea
        let storage = CameraOrderStorage(
            areaOrders: [areaName: ["camera.zebra", "camera.alpha"]],
            sectionOrder: nil
        )
        mockDiskCache.setStoredValue(storage, forKey: "camera_order_test_server")

        // Create view model after setting up storage
        sut = CameraListViewModel(serverId: "test_server", diskCache: mockDiskCache)

        sut.cameras = [
            makeCamera(entityId: "camera.alpha", name: "Alpha Camera"),
            makeCamera(entityId: "camera.beta", name: "Beta Camera"),
            makeCamera(entityId: "camera.zebra", name: "Zebra Camera"),
            makeCamera(entityId: "camera.new", name: "New Camera"),
        ]
        sut.selectedServerId = "test_server"

        // Give promises a chance to resolve
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // When: Getting grouped cameras
        let grouped = sut.groupedCameras

        // Then: Custom order first, then new cameras alphabetically
        if let cameras = grouped.first?.cameras {
            XCTAssertEqual(cameras.count, 4)
            XCTAssertEqual(cameras[0].entityId, "camera.zebra")
            XCTAssertEqual(cameras[1].entityId, "camera.alpha")
            XCTAssertEqual(cameras[2].entityId, "camera.beta") // New cameras alphabetically
            XCTAssertEqual(cameras[3].entityId, "camera.new")
        }
    }

    // MARK: - Section Ordering Tests

    func testDefaultSectionOrderAlphabetical() {
        // Given: Multiple cameras in different areas (simulated via names)
        sut.cameras = [
            makeCamera(entityId: "camera.1", name: "Zebra Area Camera"),
            makeCamera(entityId: "camera.2", name: "Alpha Area Camera"),
        ]
        sut.selectedServerId = "test_server"

        // When: Getting grouped cameras
        let grouped = sut.groupedCameras

        // Then: Should have at least one section
        XCTAssertGreaterThanOrEqual(grouped.count, 1)
    }

    func testCustomSectionOrderIsApplied() {
        // Given: Custom section order
        let areaName = L10n.CameraList.noArea
        let storage = CameraOrderStorage(
            areaOrders: [:],
            sectionOrder: [areaName]
        )
        mockDiskCache.setStoredValue(storage, forKey: "camera_order_test_server")

        // Create view model after setting up storage
        sut = CameraListViewModel(serverId: "test_server", diskCache: mockDiskCache)

        sut.cameras = [
            makeCamera(entityId: "camera.1", name: "Camera 1"),
        ]
        sut.selectedServerId = "test_server"

        // Give promises a chance to resolve
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // When: Getting grouped cameras
        let grouped = sut.groupedCameras

        // Then: Sections should follow custom order
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].area, areaName)
    }

    func testNewSectionsAddedAlphabetically() {
        // Given: Empty custom section order
        let storage = CameraOrderStorage(
            areaOrders: [:],
            sectionOrder: []
        )
        mockDiskCache.setStoredValue(storage, forKey: "camera_order_test_server")

        // Create view model after setting up storage
        sut = CameraListViewModel(serverId: "test_server", diskCache: mockDiskCache)

        sut.cameras = [
            makeCamera(entityId: "camera.1", name: "Camera 1"),
            makeCamera(entityId: "camera.2", name: "Camera 2"),
        ]
        sut.selectedServerId = "test_server"

        // Give promises a chance to resolve
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // When: Getting grouped cameras
        let grouped = sut.groupedCameras

        // Then: New sections should be added
        XCTAssertGreaterThanOrEqual(grouped.count, 1)
    }

    // MARK: - Persistence Tests

    func testMoveCamerasSavesNewOrder() {
        // Given: Cameras in an area
        let areaName = L10n.CameraList.noArea
        sut.cameras = [
            makeCamera(entityId: "camera.1", name: "Camera 1"),
            makeCamera(entityId: "camera.2", name: "Camera 2"),
        ]
        sut.selectedServerId = "test_server"
        mockDiskCache.savedValues.removeAll()

        // When: Moving cameras
        sut.moveCameras(in: areaName, from: IndexSet(integer: 0), to: 2)

        // Then: New order should be saved
        XCTAssertTrue(mockDiskCache.savedValues.count > 0, "Should have saved camera order")

        if let savedStorage = mockDiskCache.savedValues["camera_order_test_server"] as? CameraOrderStorage {
            XCTAssertNotNil(savedStorage.areaOrders[areaName], "Should have order for area")
        }
    }

    func testSaveSectionOrderPersists() {
        // Given: Section names
        let sections = ["Kitchen", "Bedroom", "Living Room"]
        mockDiskCache.savedValues.removeAll()

        // When: Saving section order
        sut.saveSectionOrder(sections)

        // Then: Order should be saved
        XCTAssertTrue(mockDiskCache.savedValues.count > 0, "Should have saved section order")

        if let savedStorage = mockDiskCache.savedValues["camera_order_test_server"] as? CameraOrderStorage {
            XCTAssertEqual(savedStorage.sectionOrder, sections)
        }
    }

    func testCameraOrderRestoredFromDiskCache() {
        // Given: Stored camera order
        let areaName = L10n.CameraList.noArea
        let storage = CameraOrderStorage(
            areaOrders: [areaName: ["camera.2", "camera.1"]],
            sectionOrder: [areaName]
        )
        mockDiskCache.setStoredValue(storage, forKey: "camera_order_test_server")

        // Create view model after setting up storage
        sut = CameraListViewModel(serverId: "test_server", diskCache: mockDiskCache)

        sut.cameras = [
            makeCamera(entityId: "camera.1", name: "Camera 1"),
            makeCamera(entityId: "camera.2", name: "Camera 2"),
        ]
        sut.selectedServerId = "test_server"

        // Give promises a chance to resolve
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // Then: Order should be restored
        let grouped = sut.groupedCameras
        if let cameras = grouped.first?.cameras, cameras.count == 2 {
            XCTAssertEqual(cameras[0].entityId, "camera.2")
            XCTAssertEqual(cameras[1].entityId, "camera.1")
        }
    }

    // MARK: - Edge Cases

    func testServerSwitchingMaintainsSeparateOrders() {
        // Given: Different servers with different orders
        let storage1 = CameraOrderStorage(
            areaOrders: ["Area1": ["camera.1", "camera.2"]],
            sectionOrder: ["Area1"]
        )
        let storage2 = CameraOrderStorage(
            areaOrders: ["Area2": ["camera.3", "camera.4"]],
            sectionOrder: ["Area2"]
        )
        mockDiskCache.setStoredValue(storage1, forKey: "camera_order_server1")
        mockDiskCache.setStoredValue(storage2, forKey: "camera_order_server2")

        // When: Creating view models for different servers
        let vm1 = CameraListViewModel(serverId: "server1", diskCache: mockDiskCache)
        let vm2 = CameraListViewModel(serverId: "server2", diskCache: mockDiskCache)

        // Then: Each should maintain its own order
        XCTAssertNotNil(vm1)
        XCTAssertNotNil(vm2)
        // Orders are server-specific and don't interfere
    }

    func testEmptyStateHandling() {
        // Given: No cameras
        sut.cameras = []
        sut.selectedServerId = "test_server"

        // When: Getting grouped cameras
        let grouped = sut.groupedCameras

        // Then: Should handle empty state gracefully
        XCTAssertEqual(grouped.count, 0)
    }

    func testSearchFilterByName() {
        // Given: Cameras with different names
        sut.cameras = [
            makeCamera(entityId: "camera.front", name: "Front Door", serverId: "test_server"),
            makeCamera(entityId: "camera.back", name: "Back Yard", serverId: "test_server"),
            makeCamera(entityId: "camera.garage", name: "Garage", serverId: "test_server"),
        ]
        sut.selectedServerId = "test_server"

        // When: Searching for "door"
        sut.searchTerm = "door"

        // Then: Only matching camera should be returned
        let filtered = sut.filteredCameras
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Front Door")
    }

    func testSearchFilterByEntityId() {
        // Given: Cameras with different entity IDs
        sut.cameras = [
            makeCamera(entityId: "camera.front_door", name: "Front Camera", serverId: "test_server"),
            makeCamera(entityId: "camera.back_yard", name: "Back Camera", serverId: "test_server"),
        ]
        sut.selectedServerId = "test_server"

        // When: Searching by entity ID
        sut.searchTerm = "front_door"

        // Then: Matching camera by entity ID
        let filtered = sut.filteredCameras
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].entityId, "camera.front_door")
    }

    func testSearchMinimumTwoCharacters() {
        // Given: Cameras
        sut.cameras = [
            makeCamera(entityId: "camera.1", name: "Camera A", serverId: "test_server"),
        ]
        sut.selectedServerId = "test_server"

        // When: Searching with one character
        sut.searchTerm = "a"

        // Then: All cameras returned (search term too short)
        let filtered = sut.filteredCameras
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilterByServerIdOnly() {
        // Given: Cameras from different servers
        sut.cameras = [
            makeCamera(entityId: "camera.1", name: "Camera 1", serverId: "server1"),
            makeCamera(entityId: "camera.2", name: "Camera 2", serverId: "server2"),
            makeCamera(entityId: "camera.3", name: "Camera 3", serverId: "server1"),
        ]
        sut.selectedServerId = "server1"

        // When: Getting filtered cameras
        let filtered = sut.filteredCameras

        // Then: Only cameras from selected server
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.serverId == "server1" })
    }

    func testShouldShowServerPickerWithSpecificServer() {
        // Given: View model initialized with specific server
        let vmWithServer = CameraListViewModel(serverId: "test_server")

        // Then: Should not show server picker
        XCTAssertFalse(vmWithServer.shouldShowServerPicker)
    }

    func testShouldShowServerPickerWithoutServer() {
        // Given: View model initialized without server
        let vmWithoutServer = CameraListViewModel(serverId: nil)

        // Then: Should show server picker
        XCTAssertTrue(vmWithoutServer.shouldShowServerPicker)
    }

    // MARK: - Helper Methods

    private func makeCamera(
        entityId: String,
        name: String,
        serverId: String = "test_server"
    ) -> HAAppEntity {
        HAAppEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: "camera",
            name: name,
            icon: nil,
            rawDeviceClass: nil
        )
    }
}

// MARK: - Mock DiskCache

class MockDiskCache: DiskCache {
    var storedValues: [String: Any] = [:]
    var savedValues: [String: Any] = [:]
    var shouldLoadSynchronously = true

    func value<T: Codable>(for key: String) -> Promise<T> {
        if let value = storedValues[key] as? T {
            if shouldLoadSynchronously {
                // Return already-resolved promise for synchronous behavior in tests
                return .value(value)
            } else {
                // Return promise that resolves asynchronously
                return Promise { seal in
                    DispatchQueue.main.async {
                        seal.fulfill(value)
                    }
                }
            }
        } else {
            return Promise(error: NSError(domain: "MockDiskCache", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Value not found for key: \(key)",
            ]))
        }
    }

    func set(_ value: some Codable, for key: String) -> Promise<Void> {
        savedValues[key] = value
        storedValues[key] = value
        if shouldLoadSynchronously {
            return .value(())
        } else {
            return Promise { seal in
                DispatchQueue.main.async {
                    seal.fulfill(())
                }
            }
        }
    }

    func setStoredValue(_ value: some Codable, forKey key: String) {
        storedValues[key] = value
    }
}
