#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI

// MARK: - Entry point

/// Deployment target is iOS 15. The settings item is filtered from the list on < iOS 17.2
/// (see SettingsItem.allVisibleCases), so this view is only ever navigated to on iOS 17.2+.
@available(iOS 17.2, *)
struct LiveActivitySettingsView: View {
    // MARK: State

    @State private var activities: [ActivitySnapshot] = []
    @State private var authorizationEnabled: Bool = false
    @State private var frequentUpdatesEnabled: Bool = false
    @State private var showEndAllConfirmation = false

    // MARK: Body

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .playBoxOutlineIcon,
                title: L10n.LiveActivity.title,
                subtitle: L10n.LiveActivity.subtitle
            )

            statusSection

            if activities.isEmpty {
                Section(L10n.LiveActivity.Section.active) {
                    HStack {
                        Text(L10n.LiveActivity.emptyState)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } else {
                Section(L10n.LiveActivity.Section.active) {
                    ForEach(activities) { snapshot in
                        ActivityRow(snapshot: snapshot) {
                            endActivity(tag: snapshot.tag)
                        }
                    }

                    Button(role: .destructive) {
                        showEndAllConfirmation = true
                    } label: {
                        Label(L10n.LiveActivity.EndAll.button, systemSymbol: .xmarkCircle)
                    }
                    .confirmationDialog(
                        L10n.LiveActivity.EndAll.Confirm.title,
                        isPresented: $showEndAllConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.LiveActivity.EndAll.Confirm.button, role: .destructive) {
                            endAllActivities()
                        }
                        Button(L10n.cancelLabel, role: .cancel) {}
                    }
                }
            }

            samplesSection
        }
        .navigationTitle(L10n.LiveActivity.title)
        .task { await loadActivities() }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                Label(L10n.LiveActivity.title, systemSymbol: .livephoto)
                Spacer()
                if authorizationEnabled {
                    Text(L10n.LiveActivity.Status.enabled)
                        .foregroundStyle(.green)
                } else if UIDevice.current.userInterfaceIdiom == .pad {
                    Text(L10n.LiveActivity.Status.notSupported)
                        .foregroundStyle(.secondary)
                } else {
                    Button(L10n.LiveActivity.Status.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.orange)
                }
            }

            HStack {
                Label(L10n.LiveActivity.FrequentUpdates.title, systemSymbol: .bolt)
                Spacer()
                if frequentUpdatesEnabled {
                    Text(L10n.LiveActivity.Status.enabled)
                        .foregroundStyle(.green)
                } else {
                    Button(L10n.LiveActivity.Status.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(L10n.LiveActivity.Section.status)
        }
    }

    // MARK: - Samples

    //
    // Two sections: Static (fixed snapshots to verify layout) and Animated (multi-stage
    // self-updating sequences to simulate real HA automation behavior).
    //
    // Each scenario tests a unique combination of ContentState fields so they can be
    // run independently without duplicating coverage.
    //
    // HOW TO USE:
    //   1. Tap any button to start the activity.
    //   2. Tap Allow on the permission prompt.
    //   3. Lock the simulator immediately (Device menu → Lock, or ⌘L).
    //   4. Watch the lock screen — animated scenarios update themselves automatically.
    //   5. End individual activities via the × button in the Active section above.
    //
    // NOTE: criticalText is only visible in the Dynamic Island compact trailing slot.
    //       It does NOT appear on the lock screen. Use a Dynamic Island device or
    //       simulator (iPhone 14 Pro+) to see it.

    private var samplesSection: some View {
        Section {
            NavigationLink("Samples") {
                List {
                    staticSamplesSection
                    animatedSamplesSection
                }
                .navigationTitle("Samples")
            }
        }
    }

    private var staticSamplesSection: some View {
        Section {
            // Minimum viable layout — only the message field is set.
            // Verifies the bare layout renders without icon, progress, or timer.
            Button("Plain Message") {
                startTestActivity(
                    tag: "debug-plain",
                    title: "Home Assistant",
                    state: .init(message: "Everything looks good at home.")
                )
            }

            // icon = nil code path. Layout must not shift or break when no icon is provided.
            // color = nil so the progress bar uses the default HA-blue tint.
            // criticalText ("Active") visible in DI compact trailing only.
            Button("No Icon · Default Color") {
                startTestActivity(
                    tag: "debug-no-icon",
                    title: "Script Running",
                    state: .init(
                        message: "Irrigation zone 3 is active",
                        criticalText: "Active",
                        progress: 35,
                        progressMax: 100
                    )
                )
            }

            // Short 60-second countdown with no progress bar.
            // Red color communicates urgency. Watch the timer count down in real time.
            // Represents automations like alarm arming delays or reminder countdowns.
            Button("Alarm · 60 sec Countdown") {
                startTestActivity(
                    tag: "debug-alarm",
                    title: "Security Alarm",
                    state: .init(
                        message: "Motion at back door · Arms in 60 seconds",
                        criticalText: "60 sec",
                        chronometer: true,
                        countdownEnd: Date().addingTimeInterval(60),
                        icon: "mdi:alarm-light",
                        color: "#F44336"
                    )
                )
            }

            // Every ContentState field active at the same time.
            // Lock screen shows: icon → live countdown → progress bar.
            // criticalText ("5 min") visible in DI compact trailing only.
            // Use this to confirm no layout collisions when all fields are populated.
            Button("All Fields · Max Load") {
                startTestActivity(
                    tag: "debug-all",
                    title: "All Fields",
                    state: .init(
                        message: "All content state fields active",
                        criticalText: "5 min",
                        progress: 42,
                        progressMax: 100,
                        chronometer: true,
                        countdownEnd: Date().addingTimeInterval(5 * 60),
                        icon: "mdi:home-assistant",
                        color: "#03A9F4"
                    )
                )
            }
        } header: {
            Text("Sample · Static")
        } footer: {
            Text("Fixed state — no updates after start. Good for checking layout at a glance.")
        }
    }

    private var animatedSamplesSection: some View {
        Section {
            // Progress bar advances through five named stages.
            // criticalText tracks the current stage name in the DI compact trailing slot.
            // Icon swaps from washing-machine to check-circle on the final update.
            // Represents any multi-step appliance cycle automation.
            Button("Washing Machine · Stage Labels (~12 s)") { startWashingMachineCycle() }

            // Numeric percentage in criticalText updates alongside the progress bar.
            // Color shifts from green to yellow-green as the charge nears 100 %.
            // Represents any "% complete with time remaining" automation pattern.
            Button("EV Charging · Numeric % (~16 s)") { startEVChargingSimulation() }

            // The only scenario where both progress (playback position) and a live countdown
            // (time remaining in track) are active and updating at the same time.
            // Simulates a track change mid-sequence: progress resets, countdown resets.
            Button("Media Player · Progress + Timer (~20 s)") { startMediaNowPlaying() }

            // Message, criticalText, and icon all change on every update — no progress bar.
            // Represents automations where the status category itself changes (not just a value).
            Button("Package Delivery · All Text Fields (~15 s)") { startPackageJourney() }

            // No progress bar — state communicated entirely through color and icon.
            // Escalates orange (motion) → red (person) → green (all clear).
            // Represents any alert-and-resolve automation pattern.
            Button("Security Escalation · Color + Icon (~8 s)") { startSecuritySequence() }

            // Cycles through wash stages then calls activity.end() with .default dismissal.
            // The only scenario that tests the full lifecycle: start → update → end.
            // After ending, the final "Done" state lingers on the lock screen (up to 4 h).
            Button("Dishwasher · Full Lifecycle, Ends Itself (~12 s)") { startDishwasherAutoComplete() }

            // Fires 6 updates 2 seconds apart (12 s total).
            // On iOS 18 the system enforces ~15 s between rendered updates — some will be
            // silently dropped. Watch the counter skip values to see the rate limit in action.
            // On the simulator and iOS 17 all 6 updates should render.
            Button("Rate Limit · 6 Rapid Updates, 2 s Apart (~12 s)") { startRapidUpdateStressTest() }
        } header: {
            Text("Sample · Animated")
        } footer: {
            Text(
                "Activity updates itself after you tap. Tap, then immediately lock (⌘L) " +
                    "to watch updates on the lock screen in real time."
            )
        }
    }

    // MARK: - Sample helpers

    /// Starts a single-state activity (no subsequent updates).
    private func startTestActivity(tag: String, title: String, state: HALiveActivityAttributes.ContentState) {
        Task {
            let attributes = HALiveActivityAttributes(tag: tag, title: title)
            _ = try? Activity<HALiveActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60)),
                pushType: nil
            )
            await loadActivities()
        }
    }

    /// Starts an activity and drives it through `stages` sequentially.
    ///
    /// - Parameters:
    ///   - stages: Array of `(delayAfterPrevious seconds, ContentState)`. The first entry's
    ///     delay is ignored — it becomes the initial content. Each subsequent entry waits
    ///     `delay` seconds after the previous stage before pushing the update.
    ///   - endAfterCompletion: When `true`, calls `activity.end()` with `.default` dismissal
    ///     after the final stage, leaving the last state visible on the lock screen (up to 4 h).
    private func startAnimatedActivity(
        tag: String,
        title: String,
        stages: [(delay: Double, state: HALiveActivityAttributes.ContentState)],
        endAfterCompletion: Bool = false
    ) {
        guard let first = stages.first else { return }
        Task {
            let attributes = HALiveActivityAttributes(tag: tag, title: title)
            guard let activity = try? Activity<HALiveActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: first.state, staleDate: Date().addingTimeInterval(30 * 60)),
                pushType: nil
            ) else { return }
            await loadActivities()
            for stage in stages.dropFirst() {
                try? await Task.sleep(nanoseconds: UInt64(stage.delay * 1_000_000_000))
                await activity.update(ActivityContent(
                    state: stage.state,
                    staleDate: Date().addingTimeInterval(30 * 60)
                ))
                await loadActivities()
            }
            if endAfterCompletion, let last = stages.last {
                await activity.end(
                    ActivityContent(state: last.state, staleDate: Date().addingTimeInterval(30 * 60)),
                    dismissalPolicy: .default
                )
                await loadActivities()
            }
        }
    }

    // MARK: - Animated scenario implementations

    /// Progress advances through five named wash stages.
    /// criticalText tracks the stage name (DI compact trailing).
    /// Icon swaps to check-circle on the final update.
    private func startWashingMachineCycle() {
        startAnimatedActivity(
            tag: "debug-washing",
            title: "Washing Machine",
            stages: [
                (0, .init(
                    message: "Starting soak",
                    criticalText: "Soak",
                    progress: 5, progressMax: 100,
                    icon: "mdi:washing-machine", color: "#2196F3"
                )),
                (3, .init(
                    message: "Washing · Heavy cycle",
                    criticalText: "Wash",
                    progress: 30, progressMax: 100,
                    icon: "mdi:washing-machine", color: "#2196F3"
                )),
                (3, .init(
                    message: "Rinsing · 1 of 2",
                    criticalText: "Rinse",
                    progress: 60, progressMax: 100,
                    icon: "mdi:washing-machine", color: "#2196F3"
                )),
                (3, .init(
                    message: "Final spin",
                    criticalText: "Spin",
                    progress: 85, progressMax: 100,
                    icon: "mdi:washing-machine", color: "#2196F3"
                )),
                (3, .init(
                    message: "Cycle complete",
                    criticalText: "Done",
                    progress: 100, progressMax: 100,
                    icon: "mdi:check-circle", color: "#4CAF50"
                )),
            ]
        )
    }

    /// Numeric percentage in criticalText updates alongside the progress bar.
    /// Color shifts from green to yellow-green as the charge nears full.
    private func startEVChargingSimulation() {
        startAnimatedActivity(
            tag: "debug-ev",
            title: "EV Charging",
            stages: [
                (0, .init(
                    message: "Charging · Est. 45 min remaining",
                    criticalText: "45%",
                    progress: 45, progressMax: 100,
                    icon: "mdi:ev-station", color: "#4CAF50"
                )),
                (4, .init(
                    message: "Charging · Est. 30 min remaining",
                    criticalText: "60%",
                    progress: 60, progressMax: 100,
                    icon: "mdi:ev-station", color: "#4CAF50"
                )),
                (4, .init(
                    message: "Charging · Est. 15 min remaining",
                    criticalText: "78%",
                    progress: 78, progressMax: 100,
                    icon: "mdi:ev-station", color: "#8BC34A"
                )),
                (4, .init(
                    message: "Charge complete",
                    criticalText: "Full",
                    progress: 100, progressMax: 100,
                    icon: "mdi:battery-charging", color: "#4CAF50"
                )),
            ]
        )
    }

    /// Both progress (playback position) and a live countdown (time remaining) update together.
    /// countdownEnd is fixed once at tap time so the timer runs smoothly across all stages.
    /// Simulates a track change: progress resets and countdownEnd resets on the final stage.
    private func startMediaNowPlaying() {
        let track1End = Date().addingTimeInterval(2 * 60)
        startAnimatedActivity(
            tag: "debug-media",
            title: "Now Playing",
            stages: [
                (0, .init(
                    message: "Bohemian Rhapsody · Queen",
                    criticalText: "1 / 12",
                    progress: 20, progressMax: 100,
                    chronometer: true, countdownEnd: track1End,
                    icon: "mdi:music-note", color: "#9C27B0"
                )),
                (5, .init(
                    message: "Bohemian Rhapsody · Queen",
                    criticalText: "1 / 12",
                    progress: 42, progressMax: 100,
                    chronometer: true, countdownEnd: track1End,
                    icon: "mdi:music-note", color: "#9C27B0"
                )),
                (5, .init(
                    message: "Bohemian Rhapsody · Queen",
                    criticalText: "1 / 12",
                    progress: 67, progressMax: 100,
                    chronometer: true, countdownEnd: track1End,
                    icon: "mdi:music-note", color: "#9C27B0"
                )),
                // Track changes — message, progress, and countdownEnd all reset together.
                (5, .init(
                    message: "Don't Stop Me Now · Queen",
                    criticalText: "2 / 12",
                    progress: 8, progressMax: 100,
                    chronometer: true, countdownEnd: Date().addingTimeInterval(3 * 60 + 29),
                    icon: "mdi:music-note", color: "#9C27B0"
                )),
            ]
        )
    }

    /// Message, criticalText, and icon all change on every update — no progress bar.
    /// Represents automations where the status category itself changes, not just a value.
    private func startPackageJourney() {
        startAnimatedActivity(
            tag: "debug-delivery",
            title: "Package Delivery",
            stages: [
                (0, .init(
                    message: "Order shipped · Est. today",
                    criticalText: "Shipped",
                    icon: "mdi:package-variant-closed", color: "#795548"
                )),
                (5, .init(
                    message: "Out for delivery · 8 stops away",
                    criticalText: "On way",
                    icon: "mdi:truck-delivery", color: "#FF9800"
                )),
                (5, .init(
                    message: "Nearby · 2 stops away",
                    criticalText: "Nearby",
                    icon: "mdi:truck-delivery", color: "#FF5722"
                )),
                (5, .init(
                    message: "Delivered to front door",
                    criticalText: "Done",
                    icon: "mdi:package-variant", color: "#4CAF50"
                )),
            ]
        )
    }

    /// State communicated through color and icon only — no progress bar.
    /// Escalates orange → red → green to show the alert-and-resolve pattern.
    private func startSecuritySequence() {
        startAnimatedActivity(
            tag: "debug-security",
            title: "Security Alert",
            stages: [
                (0, .init(
                    message: "Motion detected at front door",
                    criticalText: "Motion",
                    icon: "mdi:motion-sensor", color: "#FF9800"
                )),
                (4, .init(
                    message: "Person detected · Camera 1",
                    criticalText: "Person",
                    icon: "mdi:cctv", color: "#F44336"
                )),
                (4, .init(
                    message: "Disarmed · All clear",
                    criticalText: "Safe",
                    icon: "mdi:shield-check", color: "#4CAF50"
                )),
            ]
        )
    }

    /// Cycles through wash stages then calls activity.end() with .default dismissal.
    /// After ending, the "Done" state lingers on the lock screen for up to 4 hours —
    /// this is the expected UX for any automation that represents a completed task.
    private func startDishwasherAutoComplete() {
        startAnimatedActivity(
            tag: "debug-dishwasher",
            title: "Dishwasher",
            stages: [
                (0, .init(
                    message: "Pre-wash in progress",
                    criticalText: "Pre-wash",
                    progress: 20, progressMax: 100,
                    icon: "mdi:dishwasher", color: "#26C6DA"
                )),
                (3, .init(
                    message: "Main wash · Hot cycle",
                    criticalText: "Wash",
                    progress: 50, progressMax: 100,
                    icon: "mdi:dishwasher", color: "#26C6DA"
                )),
                (3, .init(
                    message: "Rinse and dry",
                    criticalText: "Rinse",
                    progress: 80, progressMax: 100,
                    icon: "mdi:dishwasher", color: "#26C6DA"
                )),
                (3, .init(
                    message: "Dishes are clean",
                    criticalText: "Done",
                    progress: 100, progressMax: 100,
                    icon: "mdi:check-circle", color: "#4CAF50"
                )),
            ],
            endAfterCompletion: true
        )
    }

    /// Fires 6 updates spaced 2 seconds apart (12 s total).
    /// On iOS 18 the system enforces ~15 s between rendered updates — excess updates are
    /// silently dropped and the counter will appear to skip values on device.
    /// On the simulator and iOS 17 all 6 updates should render without skipping.
    private func startRapidUpdateStressTest() {
        startAnimatedActivity(
            tag: "debug-rapid",
            title: "Rate Limit Test",
            stages: [
                (0, .init(
                    message: "Update 1 of 6 · Watch for skipped values on device",
                    criticalText: "#1",
                    progress: 0, progressMax: 100,
                    icon: "mdi:lightning-bolt", color: "#FF9800"
                )),
                (2, .init(
                    message: "Update 2 of 6",
                    criticalText: "#2",
                    progress: 17, progressMax: 100,
                    icon: "mdi:lightning-bolt", color: "#FF9800"
                )),
                (2, .init(
                    message: "Update 3 of 6",
                    criticalText: "#3",
                    progress: 33, progressMax: 100,
                    icon: "mdi:lightning-bolt", color: "#FF9800"
                )),
                (2, .init(
                    message: "Update 4 of 6",
                    criticalText: "#4",
                    progress: 50, progressMax: 100,
                    icon: "mdi:lightning-bolt", color: "#FF9800"
                )),
                (2, .init(
                    message: "Update 5 of 6",
                    criticalText: "#5",
                    progress: 67, progressMax: 100,
                    icon: "mdi:lightning-bolt", color: "#FF9800"
                )),
                (2, .init(
                    message: "Update 6 of 6 · All done",
                    criticalText: "#6",
                    progress: 100, progressMax: 100,
                    icon: "mdi:lightning-bolt", color: "#FF9800"
                )),
            ]
        )
    }

    // MARK: - Data

    private func loadActivities() async {
        let info = ActivityAuthorizationInfo()
        authorizationEnabled = info.areActivitiesEnabled
        frequentUpdatesEnabled = info.frequentPushesEnabled

        activities = Activity<HALiveActivityAttributes>.activities.map {
            ActivitySnapshot(activity: $0)
        }
    }

    private func endActivity(tag: String) {
        Task {
            await Current.liveActivityRegistry?.end(tag: tag, dismissalPolicy: .immediate)
            await loadActivities()
        }
    }

    private func endAllActivities() {
        Task {
            let tags = activities.map(\.tag)
            await withTaskGroup(of: Void.self) { group in
                for tag in tags {
                    group.addTask {
                        await Current.liveActivityRegistry?.end(tag: tag, dismissalPolicy: .immediate)
                    }
                }
            }
            await loadActivities()
        }
    }
}

// MARK: - Activity row

@available(iOS 17.2, *)
private struct ActivityRow: View {
    let snapshot: ActivitySnapshot
    let onEnd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(.body)
                Text(snapshot.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("tag: \(snapshot.tag)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button(role: .destructive, action: onEnd) {
                Image(systemSymbol: .xmarkCircleFill)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Snapshot model

@available(iOS 17.2, *)
private struct ActivitySnapshot: Identifiable {
    let id: String
    let tag: String
    let title: String
    let message: String

    init(activity: Activity<HALiveActivityAttributes>) {
        self.id = activity.id
        self.tag = activity.attributes.tag
        self.title = activity.attributes.title
        self.message = activity.content.state.message
    }
}
#endif
