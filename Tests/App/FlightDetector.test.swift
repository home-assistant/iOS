import CoreMotion
import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
@MainActor
struct FlightDetectorTests {
    // MARK: - Airline Wi-Fi

    @Test(arguments: [
        "United_Wi-Fi",
        "DeltaWiFi.com",
        "Free Wi-Fi at AlaskaWifi.com",
        "gogoinflight",
        "AA-Inflight",
        "Lufthansa FlyNet",
        "KrisWorld",
        "SAS",
        "BA",
    ])
    func airlineWiFiNamesAreRecognized(ssid: String) {
        #expect(InFlightWiFiSSIDs.matches(ssid))
    }

    @Test(arguments: ["", "Simulator", "My Home", "BA Home", "Delta House", "Starbucks WiFi"])
    func everydayWiFiNamesAreNotRecognized(ssid: String) {
        #expect(!InFlightWiFiSSIDs.matches(ssid))
    }

    @Test func airlineWiFiIsAFlight() async {
        await withSimulatedFlight(ssid: "United_Wi-Fi", networkType: .wifi) { _ in
            let isFlying = await FlightDetector.isLikelyFlying()
            #expect(isFlying)
        }
    }

    @Test func airlineWiFiWithoutInternetIsAFlight() async {
        // Onboard Wi-Fi before paying for it: associated with the network, but nothing gets through.
        await withSimulatedFlight(ssid: "gogoinflight", networkType: .noConnection) { _ in
            let isFlying = await FlightDetector.isLikelyFlying()
            #expect(isFlying)
        }
    }

    // MARK: - Cabin pressure

    @Test func cabinCruisePressureOfflineIsAFlight() async {
        await withSimulatedFlight(networkType: .noConnection, baselineKpa: 101.3) { flight in
            CabinPressureMonitor.shared.start { _ in }
            flight.read(kpa: 78)

            #expect(FlightDetector.cabinPressureIndicatesFlight)
        }
    }

    @Test func cabinCruisePressureWithANetworkIsNotAFlight() async {
        // High ground in bad weather can read like a cabin, but a device standing there has a network.
        await withSimulatedFlight(networkType: .cellular, baselineKpa: 101.3) { flight in
            CabinPressureMonitor.shared.start { _ in }
            flight.read(kpa: 78)

            #expect(!FlightDetector.cabinPressureIndicatesFlight)
        }
    }

    @Test func groundPressureOfflineIsNotAFlight() async {
        await withSimulatedFlight(networkType: .noConnection, baselineKpa: 101.3) { flight in
            CabinPressureMonitor.shared.start { _ in }
            flight.read(kpa: 101.1)

            #expect(!FlightDetector.cabinPressureIndicatesFlight)
        }
    }

    @Test func pressurizingCabinOfflineIsAFlightAndAnnouncesItself() async {
        // No baseline: a first flight after install, or one leaving a high-elevation airport.
        await withSimulatedFlight(networkType: .noConnection) { flight in
            var changes = [CabinPressureEvidence]()
            CabinPressureMonitor.shared.start { changes.append($0) }

            // Five minutes of readings five seconds apart, climbing 1.2 kPa lower every minute.
            for step in 0 ... 60 {
                flight.read(kpa: 101.3 - 1.2 * Double(step * 5) / 60, after: step == 0 ? 0 : 5)
            }

            #expect(FlightDetector.cabinPressureIndicatesFlight)
            // The announcement is what makes the greeting appear without the app being reopened.
            #expect(changes.count == 1)
            #expect(changes.first?.indicatesFlight == true)
        }
    }

    // MARK: - Greeting

    @Test func greetingShowsOncePerFlight() async {
        guard #available(iOS 18, *) else { return }
        await withSimulatedFlight(networkType: .noConnection, greetingsEnabled: true) { _ in
            FlightGreetingManager.shared.presentGreetingToastIfAllowed()
            #expect(ToastPresenter.shared.toast?.title == L10n.FlightGreetings.greeting)

            ToastPresenter.shared.hideCurrent()
            FlightGreetingManager.shared.presentGreetingToastIfAllowed()
            #expect(ToastPresenter.shared.toast == nil)
        }
    }

    @Test func greetingReturnsForTheNextFlight() async {
        guard #available(iOS 18, *) else { return }
        await withSimulatedFlight(networkType: .noConnection, greetingsEnabled: true) { flight in
            FlightGreetingManager.shared.presentGreetingToastIfAllowed()
            ToastPresenter.shared.hideCurrent()

            flight.now = flight.now.addingTimeInterval(6 * 60 * 60)
            FlightGreetingManager.shared.presentGreetingToastIfAllowed()
            #expect(ToastPresenter.shared.toast?.title == L10n.FlightGreetings.greeting)
        }
    }

    @Test func greetingRespectsTheSetting() async {
        guard #available(iOS 18, *) else { return }
        await withSimulatedFlight(networkType: .noConnection, greetingsEnabled: false) { _ in
            FlightGreetingManager.shared.presentGreetingToastIfAllowed()
            #expect(ToastPresenter.shared.toast == nil)
        }
    }

    // MARK: - Helpers

    private final class SimulatedFlight {
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var barometerHandler: CMAltitudeHandler?

        func read(kpa: Double, after seconds: TimeInterval = 0) {
            now = now.addingTimeInterval(seconds)
            barometerHandler?(SimulatedAltitudeData(pressureKpa: kpa), nil)
        }
    }

    private final class SimulatedAltitudeData: CMAltitudeData {
        private let pressureKpa: NSNumber

        init(pressureKpa: Double) {
            self.pressureKpa = NSNumber(value: pressureKpa)
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override var pressure: NSNumber {
            pressureKpa
        }

        override var relativeAltitude: NSNumber {
            NSNumber(value: 0)
        }
    }

    /// Runs `body` with the network, barometer, clock, pressure baseline and greeting state under test
    /// control, restoring all of them afterwards. Barometer readings are delivered synchronously.
    private func withSimulatedFlight(
        ssid: String? = nil,
        networkType: NetworkType,
        baselineKpa: Double? = nil,
        greetingsEnabled: Bool = true,
        _ body: (SimulatedFlight) async -> Void
    ) async {
        let flight = SimulatedFlight()
        let previousNetworkState = Current.connectivity.currentNetworkState
        let previousNetworkType = Current.connectivity.simpleNetworkType
        let previousBarometer = Current.barometer
        let previousDate = Current.date
        let previousGreetingsEnabled = Current.settingsStore.flightGreetingsEnabled
        let storedKeys = [
            CabinPressureMonitor.baselinePressureKey,
            CabinPressureMonitor.baselineDateKey,
            FlightGreetingManager.lastGreetingDateKey,
        ]
        let previousStoredValues = storedKeys.map { prefs.object(forKey: $0) }
        defer {
            CabinPressureMonitor.shared.stop()
            if #available(iOS 18, *) {
                ToastPresenter.shared.hideCurrent()
            }
            Current.connectivity.currentNetworkState = previousNetworkState
            Current.connectivity.simpleNetworkType = previousNetworkType
            Current.barometer = previousBarometer
            Current.date = previousDate
            Current.settingsStore.flightGreetingsEnabled = previousGreetingsEnabled
            for (key, value) in zip(storedKeys, previousStoredValues) {
                prefs.set(value, forKey: key)
            }
        }

        Current.connectivity.currentNetworkState = { NetworkState(ssid: ssid) }
        Current.connectivity.simpleNetworkType = { networkType }
        Current.date = { flight.now }
        Current.barometer.isAvailable = { true }
        Current.barometer.isAuthorized = { true }
        Current.barometer.startUpdatesOnQueueHandler = { _, handler in
            flight.barometerHandler = handler
        }
        Current.barometer.stopUpdates = {
            flight.barometerHandler = nil
        }
        Current.settingsStore.flightGreetingsEnabled = greetingsEnabled
        for key in storedKeys {
            prefs.removeObject(forKey: key)
        }
        if let baselineKpa {
            prefs.set(baselineKpa, forKey: CabinPressureMonitor.baselinePressureKey)
            prefs.set(flight.now.addingTimeInterval(-60 * 60), forKey: CabinPressureMonitor.baselineDateKey)
        }
        if #available(iOS 18, *) {
            ToastPresenter.shared.hideCurrent()
        }

        await body(flight)
    }
}
