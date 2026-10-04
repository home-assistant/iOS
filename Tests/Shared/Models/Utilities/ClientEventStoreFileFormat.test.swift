import Foundation
@testable import Shared
import XCTest

final class ClientEventStoreFileFormatTests: XCTestCase {
    private var store: ClientEventStore!

    override func setUp() {
        super.setUp()
        store = ClientEventStore()
        store.clearAllEvents()
    }

    override func tearDown() {
        store.clearAllEvents()
        store = nil
        super.tearDown()
    }

    private func line(for event: ClientEvent) throws -> Data {
        var data = try JSONEncoder().encode(event)
        data.append(UInt8(ascii: "\n"))
        return data
    }

    func testMissingFileReadsAsEmpty() throws {
        try FileManager.default.removeItem(at: AppConstants.clientEventsFile)
        XCTAssertTrue(store.getEvents().isEmpty)
    }

    func testEmptyFileReadsAsEmpty() throws {
        try Data().write(to: AppConstants.clientEventsFile, options: .atomic)
        XCTAssertTrue(store.getEvents().isEmpty)
    }

    func testCorruptLegacyArrayReadsAsEmpty() throws {
        try Data("[not json".utf8).write(to: AppConstants.clientEventsFile, options: .atomic)
        XCTAssertTrue(store.getEvents().isEmpty)
    }

    func testCorruptLineIsSkippedAndOthersAreKept() throws {
        var data = try line(for: ClientEvent(text: "Before", type: .settings))
        data.append(Data("{\"garbage\": true}\n".utf8))
        try data.append(line(for: ClientEvent(text: "After", type: .database)))
        try data.write(to: AppConstants.clientEventsFile, options: .atomic)

        let events = store.getEvents()
        XCTAssertEqual(events.map(\.text), ["Before", "After"])
        XCTAssertEqual(events.map(\.type), [.settings, .database])
    }

    func testAppendsAfterClearKeepPayload() {
        store.addEvent(ClientEvent(text: "Payload", type: .backgroundOperation, payload: ["key": "value"]))

        let events = store.getEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.jsonPayload["key"], AnyCodable("value"))
    }

    func testManyAppendsAreAllReadBack() {
        for index in 0 ..< 120 {
            store.addEvent(ClientEvent(text: "Event \(index)", type: .unknown))
        }

        let events = store.getEvents()
        XCTAssertEqual(events.count, 120)
        XCTAssertEqual(events.first?.text, "Event 0")
        XCTAssertEqual(events.last?.text, "Event 119")
    }
}
