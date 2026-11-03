import AVFoundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// What each sensor permission is called and shown as, how every platform status maps onto the
/// app's own, and the parts of the requester that never put a system prompt on screen.
///
/// `.sharedState`: the permissions screen and the requester are driven through the shared
/// `SensorPermissionRequester`.
@Suite(.sharedState)
@MainActor
struct SensorPermissionTests {
    private static let allStatuses: [SensorPermissionStatus] = [
        .notDetermined, .granted, .authorizedAlways, .authorizedWhenInUse, .denied, .restricted, .unknown,
    ]

    @Test func everyPermissionHasATitleUsageAndIcon() {
        for permission in SensorPermission.allCases {
            #expect(permission.id == permission.rawValue)
            #expect(!permission.title.isEmpty)
            #expect(!permission.usageDescription.isEmpty)
            _ = permission.icon
        }
    }

    @Test func statusesDescribeThemselves() {
        for status in Self.allStatuses {
            _ = status.color
            #expect(status.description.isEmpty == (status == .unknown))
        }
        #expect(SensorPermissionStatus.granted.color == .green)
        #expect(SensorPermissionStatus.denied.color == .yellow)
        #expect(SensorPermissionStatus.notDetermined.color == .secondary)
    }

    @Test func audioSessionPermissionsMap() {
        #expect(SensorPermissionStatus(AVAudioSession.RecordPermission.undetermined) == .notDetermined)
        #expect(SensorPermissionStatus(AVAudioSession.RecordPermission.denied) == .denied)
        #expect(SensorPermissionStatus(AVAudioSession.RecordPermission.granted) == .granted)
    }

    @Test func requesterReportsAvailabilityAndStatusForEveryPermission() {
        let requester = SensorPermissionRequester.shared
        for permission in SensorPermission.allCases {
            _ = requester.isAvailable(permission)
            let status = requester.status(for: permission)
            if permission == .notification || permission == .localNetwork {
                #expect(status == .unknown)
            }
        }
        #expect(requester.isAvailable(.location))
    }

    /// Neither of these can prompt: the sensors need no permission, and local network access is
    /// only ever asked for by the system itself.
    @Test func requestsThatNeedNoPromptReturnAtOnce() {
        let requester = SensorPermissionRequester.shared
        requester.requestPermissionsIfNeeded(forSensorUniqueIDs: ["battery_level", "no_such_sensor"])
        requester.request(.localNetwork)
        #expect(SensorPermission.required(forSensorUniqueID: "no_such_sensor") == nil)
    }

    /// A sensor needing an unanswered permission queues it, asks for it (through Focus's injectable
    /// request, so no system prompt shows), reports the change and then refreshes the sensors; the
    /// refresh is stopped by a background task runner with no time left. Once answered, asking again
    /// does nothing.
    @Test func anUnansweredPermissionIsAskedForAndTheSensorsRefreshed() async throws {
        let focus = Current.focusStatus
        let previousAvailable = focus.isAvailable
        let previousStatus = focus.authorizationStatus
        let previousRequest = focus.requestAuthorization
        let previousRunner = Current.backgroundTask
        defer {
            focus.isAvailable = previousAvailable
            focus.authorizationStatus = previousStatus
            focus.requestAuthorization = previousRequest
            Current.backgroundTask = previousRunner
        }
        var status = FocusStatusWrapper.AuthorizationStatus.notDetermined
        var requests = 0
        focus.isAvailable = { true }
        focus.authorizationStatus = { status }
        focus.requestAuthorization = {
            requests += 1
            status = .authorized
            return .value(.authorized)
        }
        Current.backgroundTask = NoTimeBackgroundTaskRunner()

        let requester = SensorPermissionRequester.shared
        var changes = 0
        let subscription = requester.statusDidChange.sink { changes += 1 }
        defer { subscription.cancel() }

        requester.requestPermissionsIfNeeded(forSensorUniqueIDs: [WebhookSensorId.focus.rawValue])
        for _ in 0 ..< 1000 where changes == 0 {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(changes == 1)
        #expect(requests == 1)

        requester.request(.focus)
        #expect(requests == 1)

        // The permissions screen asks again for a permission that is unanswered once more, from its
        // view model and from its row.
        status = .notDetermined
        let viewModel = SensorPermissionsViewModel()
        viewModel.handleTap(on: .focus)
        #expect(requests == 2)

        status = .notDetermined
        let row = try #require(viewModel.availablePermissions.firstIndex(of: .focus))
        let driver = await SwiftUIScreenDriver.show(SensorPermissionsView())
        defer { driver.close() }
        let rows = driver.rows
        try #require(row < rows.count)
        await driver.tapRow(rows[row])
        await #expect(driver.waitUntil { requests == 3 })
    }

    /// Tapping a permission that was already answered sends the user to its page in Settings.
    @Test func tappingAnAnsweredPermissionOpensItsSettingsPage() async {
        let focus = Current.focusStatus
        let previousAvailable = focus.isAvailable
        let previousStatus = focus.authorizationStatus
        defer {
            focus.isAvailable = previousAvailable
            focus.authorizationStatus = previousStatus
        }
        focus.isAvailable = { true }
        focus.authorizationStatus = { .denied }

        await RecordingURLOpener.with { opener in
            let viewModel = SensorPermissionsViewModel()
            #expect(viewModel.status(for: .focus) != .notDetermined)
            viewModel.handleTap(on: .focus)
            #expect(opener.openSettingsDestination == viewModel.settingsDestination(for: .focus))
        }
    }

    /// An answered permission can only be changed in the Settings app, at its own page.
    @Test func everyPermissionOpensItsOwnSettingsPage() {
        let viewModel = SensorPermissionsViewModel()
        let destinations = SensorPermission.allCases.map { viewModel.settingsDestination(for: $0) }
        #expect(destinations.count == SensorPermission.allCases.count)
        #expect(viewModel.settingsDestination(for: .location) == .location)
        #expect(viewModel.settingsDestination(for: .localNetwork) == .localNetwork)
    }

    @Test func permissionsScreenListsEveryAvailablePermissionAndRefreshes() async {
        let harness = await SettingsScreenHarness.show(SensorPermissionsView())
        let viewModel = SensorPermissionsViewModel()
        await #expect(harness.waitUntil { harness.rows.count == viewModel.availablePermissions.count })

        SensorPermissionRequester.shared.statusDidChange.send()
        await harness.settle()
        #expect(viewModel.notDeterminedCount <= viewModel.availablePermissions.count)
        await harness.close()
    }
}

/// Fails every background task at once, without running the work it wraps.
private final class NoTimeBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        Promise(error: BackgroundTaskError.outOfTime)
    }
}
