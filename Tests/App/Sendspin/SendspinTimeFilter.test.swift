import Foundation
@testable import HomeAssistant
import Testing

/// Expected values come from `aiosendspin`'s port of the reference filter fed the same samples.
struct SendspinTimeFilterTests {
    private func feed(_ count: Int) -> [Int: SendspinTimeFilter] {
        var filter = SendspinTimeFilter()
        var snapshots: [Int: SendspinTimeFilter] = [:]
        for index in 1 ... count {
            let time = Int64(index * 250_000)
            let measurement = 5_000_000 + Int64((Double(time) * 50e-6).rounded(.toNearestOrEven)) +
                Int64(((index * 37) % 7 - 3) * 20)
            let maxError = Int64(1000 + ((index * 13) % 5) * 100)
            filter.update(measurement: measurement, maxError: maxError, timeAdded: time)
            snapshots[index] = filter
        }
        return snapshots
    }

    @Test func tracksTheReferenceFilter() throws {
        let snapshots = feed(30)
        let expected: [(index: Int, synchronized: Bool, error: Int64, server: Int64, client: Int64)] = [
            (1, false, 650, 5_250_992, 350_008),
            (2, true, 550, 5_501_045, 599_955),
            (3, true, 576, 5_751_098, 849_902),
            (10, true, 344, 7_501_143, 2_599_857),
            (30, true, 210, 12_501_375, 7_599_625),
        ]
        for row in expected {
            let filter = try #require(snapshots[row.index])
            let time = Int64(row.index * 250_000)
            #expect(filter.isSynchronized == row.synchronized, "sample \(row.index)")
            #expect(filter.error == row.error, "sample \(row.index)")
            #expect(filter.mapping.serverTime(fromClient: time + 1000) == row.server, "sample \(row.index)")
            #expect(filter.mapping.clientTime(fromServer: time + 5_100_000) == row.client, "sample \(row.index)")
        }
    }

    @Test func ignoresSamplesThatGoBackInTime() {
        var filter = SendspinTimeFilter()
        filter.update(measurement: 100, maxError: 10, timeAdded: 1000)
        filter.update(measurement: 999_999, maxError: 10, timeAdded: 500)
        #expect(filter.count == 1)
        #expect(filter.offset == 100)
    }

    @Test func samplesOftenUntilConverged() {
        var filter = SendspinTimeFilter()
        #expect(filter.error == .max)
        #expect(filter.nextSampleInterval == 0.2)
        filter.update(measurement: 100, maxError: 400, timeAdded: 1000)
        filter.update(measurement: 100, maxError: 400, timeAdded: 2000)
        #expect(filter.nextSampleInterval == 3)
        filter.update(measurement: 100, maxError: 3000, timeAdded: 3000)
        #expect(filter.nextSampleInterval >= 0.2)
    }

    /// The NTP-style exchange: half the round trip is the uncertainty, the midpoint the offset.
    @Test func convertsAnExchangeIntoAMeasurement() {
        var filter = SendspinTimeFilter()
        filter.update(
            sample: SendspinServerTime(clientTransmitted: 1000, serverReceived: 6000, serverTransmitted: 6200),
            receivedAt: 1400
        )
        #expect(filter.offset == 4900)
        #expect(filter.count == 1)
    }
}
