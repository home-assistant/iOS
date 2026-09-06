import Foundation
@testable import HomeAssistant
import Testing

struct SendspinClockFilterTests {
    /// Feeds the filter a synthetic exchange for a server whose clock sits `offset` microseconds
    /// ahead and runs `drift` faster, with a symmetric round trip.
    private func feed(
        _ filter: inout SendspinClockFilter,
        count: Int,
        offset: Double,
        drift: Double = 0,
        roundTrip: Int64 = 4_000,
        interval: Int64 = 250_000
    ) {
        for index in 0 ..< count {
            let clientTransmitted = Int64(index) * interval
            let clientReceived = clientTransmitted + roundTrip
            let midpoint = Double(clientTransmitted) + Double(roundTrip) / 2
            let serverTime = Int64(midpoint + offset + drift * midpoint)
            filter.update(
                clientTransmitted: clientTransmitted,
                serverReceived: serverTime,
                serverTransmitted: serverTime,
                clientReceived: clientReceived
            )
        }
    }

    @Test func convergesOnAConstantOffset() throws {
        var filter = SendspinClockFilter()
        #expect(filter.isConverged == false)
        feed(&filter, count: 20, offset: 250_000)
        #expect(filter.isConverged)
        let snapshot = try #require(filter.snapshot)
        #expect(abs(snapshot.offsetMicroseconds - 250_000) < 1_000)
    }

    @Test func mapsBetweenTheTwoClocks() throws {
        var filter = SendspinClockFilter()
        feed(&filter, count: 20, offset: 250_000)
        let snapshot = try #require(filter.snapshot)
        let local: Double = 10_000_000
        let server = snapshot.serverTime(forLocal: local)
        #expect(abs(snapshot.localTime(forServer: server) - local) < 1)
    }

    /// The drift state is what keeps a player aligned over hours rather than seconds.
    @Test func tracksAClockRunningFast() throws {
        var filter = SendspinClockFilter()
        feed(&filter, count: 60, offset: 100_000, drift: 50e-6)
        let snapshot = try #require(filter.snapshot)
        #expect(snapshot.driftPerMicrosecond > 0)
        let predicted = snapshot.serverTime(forLocal: 20_000_000)
        let truth = 20_000_000 + 100_000 + 50e-6 * 20_000_000
        #expect(abs(predicted - truth) < 5_000)
    }

    /// A round trip that reports the server answering before the request arrived is nonsense, and
    /// must not be allowed to poison the estimate.
    @Test func ignoresImpossibleRoundTrips() {
        var filter = SendspinClockFilter()
        filter.update(clientTransmitted: 1_000, serverReceived: 0, serverTransmitted: 5_000, clientReceived: 1_100)
        #expect(filter.snapshot == nil)
    }
}
