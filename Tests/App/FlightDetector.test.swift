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
            #expect(changes.count == 1)
            #expect(changes.first?.indicatesFlight == true)
        }
    }

    @Test func cabinPressureShowsTheGreetingWhileTheAppIsOpen() async {
        guard #available(iOS 18, *) else { return }
        await withSimulatedFlight(networkType: .noConnection, baselineKpa: 101.3) { flight in
            FlightGreetingManager.shared.startPressureMonitoringIfNeeded()
            flight.read(kpa: 78)

            // The manager hands the monitor's verdict to the main actor before greeting.
            for _ in 0 ..< 100 where ToastPresenter.shared.toast == nil {
                try? await Task.sleep(for: .milliseconds(10))
            }
            #expect(ToastPresenter.shared.toast?.title == L10n.FlightGreetings.greeting)
        }
    }

    @Test func cabinPressureDoesNotGreetWhenGreetingsAreOff() async {
        guard #available(iOS 18, *) else { return }
        await withSimulatedFlight(networkType: .noConnection, baselineKpa: 101.3, greetingsEnabled: false) { flight in
            FlightGreetingManager.shared.startPressureMonitoringIfNeeded()
            flight.read(kpa: 78)
            try? await Task.sleep(for: .milliseconds(100))

            #expect(!CabinPressureMonitor.shared.isObserving)
            #expect(ToastPresenter.shared.toast == nil)
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

    /// Runs `body` with `Current` scoped to an environment whose network, clock and barometer (including its
    /// observer) are under test control, so nothing outside the scenario sees them. The pressure baseline,
    /// greeting cooldown and setting live in user defaults, which no environment isolates, so those are saved
    /// and restored around it. Barometer readings are delivered synchronously.
    private func withSimulatedFlight(
        ssid: String? = nil,
        networkType: NetworkType,
        baselineKpa: Double? = nil,
        greetingsEnabled: Bool = true,
        _ body: (SimulatedFlight) async -> Void
    ) async {
        let flight = SimulatedFlight()
        let environment = AppEnvironment()
        environment.connectivity.currentNetworkState = { NetworkState(ssid: ssid) }
        environment.connectivity.simpleNetworkType = { networkType }
        environment.date = { flight.now }
        environment.barometer.isAvailable = { true }
        environment.barometer.isAuthorized = { true }
        environment.barometer.startUpdatesOnQueueHandler = { _, handler in
            flight.barometerHandler = handler
        }
        environment.barometer.stopUpdates = {
            flight.barometerHandler = nil
        }
        environment.barometerObserver = BarometerObserver()

        let previousGreetingsEnabled = environment.settingsStore.flightGreetingsEnabled
        let storedKeys = [
            CabinPressureMonitor.baselinePressureKey,
            CabinPressureMonitor.baselineDateKey,
            FlightGreetingManager.lastGreetingDateKey,
        ]
        let previousStoredValues = storedKeys.map { prefs.object(forKey: $0) }
        defer {
            environment.settingsStore.flightGreetingsEnabled = previousGreetingsEnabled
            for (key, value) in zip(storedKeys, previousStoredValues) {
                prefs.set(value, forKey: key)
            }
        }

        environment.settingsStore.flightGreetingsEnabled = greetingsEnabled
        for key in storedKeys {
            prefs.removeObject(forKey: key)
        }
        if let baselineKpa {
            prefs.set(baselineKpa, forKey: CabinPressureMonitor.baselinePressureKey)
            prefs.set(flight.now.addingTimeInterval(-60 * 60), forKey: CabinPressureMonitor.baselineDateKey)
        }

        await withCurrent(environment) {
            if #available(iOS 18, *) {
                ToastPresenter.shared.hideCurrent()
            }
            await body(flight)
            // Stopped inside the scope, so it releases this scenario's barometer rather than the global one.
            CabinPressureMonitor.shared.stop()
            if #available(iOS 18, *) {
                ToastPresenter.shared.hideCurrent()
            }
        }
    }
}
