#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI

@available(iOS 17.2, *)
struct LiveActivitySettingsView: View {
    // MARK: State

    @State private var activities: [ActivitySnapshot] = []
    @State private var authorizationEnabled: Bool = false
    @State private var frequentUpdatesEnabled: Bool = false
    @State private var showEndAllConfirmation = false
    @State private var didSync = false

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

                    Button {
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

            Section {
                Button {
                    syncActivities()
                } label: {
                    Label(L10n.LiveActivity.Sync.button, systemSymbol: .arrowTriangle2Circlepath)
                }

                if didSync {
                    Label(L10n.LiveActivity.Sync.done, systemSymbol: .checkmarkCircleFill)
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            } footer: {
                Text(L10n.LiveActivity.Sync.footer)
            }

            samplesSection

            Section {
                Link(destination: AppConstants.WebURLs.liveActivitiesDocs) {
                    HStack {
                        Text(L10n.LiveActivity.documentation)
                        Spacer()
                        Image(systemSymbol: .arrowUpForwardSquare)
                            .font(.caption)
                    }
                }
            }
        }
        .task { await loadActivities() }
    }

    private func syncActivities() {
        Task {
            await Current.liveActivityRegistry?.reattach()
            await loadActivities()
            didSync = true
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                Label(L10n.LiveActivity.title, systemSymbol: .livephoto)
                Spacer()
                if !isLiveActivitySupportedOnDevice {
                    Text(L10n.LiveActivity.Status.notSupported)
                        .foregroundStyle(.secondary)
                } else if authorizationEnabled {
                    Text(L10n.LiveActivity.Status.enabled)
                        .foregroundStyle(.green)
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
                if !isLiveActivitySupportedOnDevice {
                    Text(L10n.LiveActivity.Status.notSupported)
                        .foregroundStyle(.secondary)
                } else if frequentUpdatesEnabled {
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

    private var isLiveActivitySupportedOnDevice: Bool {
        UIDevice.current.userInterfaceIdiom != .pad
    }

    private var samplesSection: some View {
        Section {
            NavigationLink(L10n.LiveActivity.Samples.title) {
                List {
                    Section {
                        ForEach(staticSamples) { sample in
                            sampleLink(sample)
                        }
                    } header: {
                        Text(L10n.LiveActivity.Samples.staticTitle)
                    } footer: {
                        Text(L10n.LiveActivity.Samples.staticFooter)
                    }

                    Section {
                        ForEach(animatedSamples) { sample in
                            sampleLink(sample)
                        }
                    } header: {
                        Text(L10n.LiveActivity.Samples.animatedTitle)
                    } footer: {
                        Text(L10n.LiveActivity.Samples.animatedFooter)
                    }
                }
                .navigationTitle(L10n.LiveActivity.Samples.title)
            }
        }
    }

    private func sampleLink(_ sample: LiveActivitySample) -> some View {
        NavigationLink {
            LiveActivitySampleDetailView(sample: sample, onStart: start)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(sample.name)
                Text(sample.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sample catalog

    private var staticSamples: [LiveActivitySample] {
        [
            LiveActivitySample(
                id: "plain",
                name: L10n.LiveActivity.Sample.Plain.title,
                summary: L10n.LiveActivity.Sample.Plain.summary,
                note: L10n.LiveActivity.Sample.Plain.note,
                tag: "debug-plain",
                title: "Home Assistant",
                stages: [.init(message: "Everything looks good at home.")]
            ),
            LiveActivitySample(
                id: "no-icon",
                name: L10n.LiveActivity.Sample.NoIcon.title,
                summary: L10n.LiveActivity.Sample.NoIcon.summary,
                note: L10n.LiveActivity.Sample.NoIcon.note,
                tag: "debug-no-icon",
                title: "Script Running",
                stages: [.init(
                    message: "Irrigation zone 3 is active",
                    criticalText: "Active",
                    progress: 35,
                    progressMax: 100
                )]
            ),
            LiveActivitySample(
                id: "alarm",
                name: L10n.LiveActivity.Sample.Alarm.title,
                summary: L10n.LiveActivity.Sample.Alarm.summary,
                note: L10n.LiveActivity.Sample.Alarm.note,
                tag: "debug-alarm",
                title: "Security Alarm",
                stages: [.init(
                    message: "Motion at back door · Arms in 60 seconds",
                    criticalText: "60 sec",
                    countdownSeconds: 60,
                    icon: "mdi:alarm-light",
                    color: "#F44336"
                )]
            ),
            LiveActivitySample(
                id: "count-up",
                name: L10n.LiveActivity.Sample.CountUp.title,
                summary: L10n.LiveActivity.Sample.CountUp.summary,
                note: L10n.LiveActivity.Sample.CountUp.note,
                tag: "debug-count-up",
                title: "Washing Machine",
                stages: [.init(
                    message: "Running...",
                    countdownSeconds: 0,
                    icon: "mdi:washing-machine",
                    color: "#FF9800"
                )]
            ),
            LiveActivitySample(
                id: "count-up-target",
                name: L10n.LiveActivity.Sample.CountUpTarget.title,
                summary: L10n.LiveActivity.Sample.CountUpTarget.summary,
                note: L10n.LiveActivity.Sample.CountUpTarget.note,
                tag: "debug-count-up-target",
                title: "Workout",
                stages: [.init(
                    message: "Session in progress",
                    countdownSeconds: -20 * 60,
                    icon: "mdi:run",
                    color: "#4CAF50",
                    progressBarColor: "#4CAF50"
                )]
            ),
            LiveActivitySample(
                id: "count-down",
                name: L10n.LiveActivity.Sample.CountDown.title,
                summary: L10n.LiveActivity.Sample.CountDown.summary,
                note: L10n.LiveActivity.Sample.CountDown.note,
                tag: "debug-count-down",
                title: "Oven Timer",
                stages: [.init(
                    message: "Pizza in the oven",
                    countdownSeconds: 45 * 60,
                    icon: "mdi:stove",
                    color: "#F44336",
                    progressBarColor: "#F44336"
                )]
            ),
            LiveActivitySample(
                id: "progress-direction",
                name: L10n.LiveActivity.Sample.ProgressDirection.title,
                summary: L10n.LiveActivity.Sample.ProgressDirection.summary,
                note: L10n.LiveActivity.Sample.ProgressDirection.note,
                tag: "debug-progress-direction",
                title: "Backup Battery",
                stages: [.init(
                    message: "On battery · 35% remaining",
                    criticalText: "35%",
                    progress: 65,
                    progressMax: 100,
                    icon: "mdi:battery-40",
                    color: "#FF9800",
                    progressBarColor: "#FF9800",
                    progressBarDirection: "decreasing"
                )]
            ),
            LiveActivitySample(
                id: "all-fields",
                name: L10n.LiveActivity.Sample.AllFields.title,
                summary: L10n.LiveActivity.Sample.AllFields.summary,
                note: L10n.LiveActivity.Sample.AllFields.note,
                tag: "debug-all",
                title: "All Fields",
                stages: [.init(
                    message: "All content state fields active",
                    criticalText: "5 min",
                    progress: 42,
                    progressMax: 100,
                    countdownSeconds: 5 * 60,
                    icon: "mdi:home-assistant",
                    color: "#03A9F4"
                )]
            ),
            LiveActivitySample(
                id: "custom-colors",
                name: L10n.LiveActivity.Sample.CustomColors.title,
                summary: L10n.LiveActivity.Sample.CustomColors.summary,
                note: L10n.LiveActivity.Sample.CustomColors.note,
                tag: "debug-colors",
                title: "Movie Night",
                stages: [.init(
                    message: "Theater mode · Lights dimmed",
                    icon: "mdi:movie-open",
                    color: "#FFD166",
                    backgroundColor: "#0B1E3F",
                    textColor: "#FFD166"
                )]
            ),
        ]
    }

    private var animatedSamples: [LiveActivitySample] {
        [
            LiveActivitySample(
                id: "washing",
                name: L10n.LiveActivity.Sample.Washing.title,
                summary: L10n.LiveActivity.Sample.Washing.summary,
                note: L10n.LiveActivity.Sample.Washing.note,
                tag: "debug-washing",
                title: "Washing Machine",
                stages: [
                    .init(
                        message: "Starting soak",
                        criticalText: "Soak",
                        progress: 5,
                        progressMax: 100,
                        icon: "mdi:washing-machine",
                        color: "#2196F3"
                    ),
                    .init(
                        delay: 3,
                        message: "Washing · Heavy cycle",
                        criticalText: "Wash",
                        progress: 30,
                        progressMax: 100,
                        icon: "mdi:washing-machine",
                        color: "#2196F3"
                    ),
                    .init(
                        delay: 3,
                        message: "Rinsing · 1 of 2",
                        criticalText: "Rinse",
                        progress: 60,
                        progressMax: 100,
                        icon: "mdi:washing-machine",
                        color: "#2196F3"
                    ),
                    .init(
                        delay: 3,
                        message: "Final spin",
                        criticalText: "Spin",
                        progress: 85,
                        progressMax: 100,
                        icon: "mdi:washing-machine",
                        color: "#2196F3"
                    ),
                    .init(
                        delay: 3,
                        message: "Cycle complete",
                        criticalText: "Done",
                        progress: 100,
                        progressMax: 100,
                        icon: "mdi:check-circle",
                        color: "#4CAF50"
                    ),
                ]
            ),
            LiveActivitySample(
                id: "ev",
                name: L10n.LiveActivity.Sample.Ev.title,
                summary: L10n.LiveActivity.Sample.Ev.summary,
                note: L10n.LiveActivity.Sample.Ev.note,
                tag: "debug-ev",
                title: "EV Charging",
                stages: [
                    .init(
                        message: "Charging · Est. 45 min remaining",
                        criticalText: "45%",
                        progress: 45,
                        progressMax: 100,
                        icon: "mdi:ev-station",
                        color: "#4CAF50"
                    ),
                    .init(
                        delay: 4,
                        message: "Charging · Est. 30 min remaining",
                        criticalText: "60%",
                        progress: 60,
                        progressMax: 100,
                        icon: "mdi:ev-station",
                        color: "#4CAF50"
                    ),
                    .init(
                        delay: 4,
                        message: "Charging · Est. 15 min remaining",
                        criticalText: "78%",
                        progress: 78,
                        progressMax: 100,
                        icon: "mdi:ev-station",
                        color: "#8BC34A"
                    ),
                    .init(
                        delay: 4,
                        message: "Charge complete",
                        criticalText: "Full",
                        progress: 100,
                        progressMax: 100,
                        icon: "mdi:battery-charging",
                        color: "#4CAF50"
                    ),
                ]
            ),
            LiveActivitySample(
                id: "media",
                name: L10n.LiveActivity.Sample.Media.title,
                summary: L10n.LiveActivity.Sample.Media.summary,
                note: L10n.LiveActivity.Sample.Media.note,
                tag: "debug-media",
                title: "Now Playing",
                stages: [
                    .init(
                        message: "Bohemian Rhapsody · Queen",
                        criticalText: "1 / 12",
                        progress: 20,
                        progressMax: 100,
                        countdownSeconds: 2 * 60,
                        icon: "mdi:music-note",
                        color: "#9C27B0"
                    ),
                    .init(
                        delay: 5,
                        message: "Bohemian Rhapsody · Queen",
                        criticalText: "1 / 12",
                        progress: 42,
                        progressMax: 100,
                        countdownSeconds: 2 * 60 - 5,
                        icon: "mdi:music-note",
                        color: "#9C27B0"
                    ),
                    .init(
                        delay: 5,
                        message: "Bohemian Rhapsody · Queen",
                        criticalText: "1 / 12",
                        progress: 67,
                        progressMax: 100,
                        countdownSeconds: 2 * 60 - 10,
                        icon: "mdi:music-note",
                        color: "#9C27B0"
                    ),
                    .init(
                        delay: 5,
                        message: "Don't Stop Me Now · Queen",
                        criticalText: "2 / 12",
                        progress: 8,
                        progressMax: 100,
                        countdownSeconds: 3 * 60 + 29,
                        icon: "mdi:music-note",
                        color: "#9C27B0"
                    ),
                ]
            ),
            LiveActivitySample(
                id: "delivery",
                name: L10n.LiveActivity.Sample.Delivery.title,
                summary: L10n.LiveActivity.Sample.Delivery.summary,
                note: L10n.LiveActivity.Sample.Delivery.note,
                tag: "debug-delivery",
                title: "Package Delivery",
                stages: [
                    .init(
                        message: "Order shipped · Est. today",
                        criticalText: "Shipped",
                        icon: "mdi:package-variant-closed",
                        color: "#795548"
                    ),
                    .init(
                        delay: 5,
                        message: "Out for delivery · 8 stops away",
                        criticalText: "On way",
                        icon: "mdi:truck-delivery",
                        color: "#FF9800"
                    ),
                    .init(
                        delay: 5,
                        message: "Nearby · 2 stops away",
                        criticalText: "Nearby",
                        icon: "mdi:truck-delivery",
                        color: "#FF5722"
                    ),
                    .init(
                        delay: 5,
                        message: "Delivered to front door",
                        criticalText: "Done",
                        icon: "mdi:package-variant",
                        color: "#4CAF50"
                    ),
                ]
            ),
            LiveActivitySample(
                id: "security",
                name: L10n.LiveActivity.Sample.Security.title,
                summary: L10n.LiveActivity.Sample.Security.summary,
                note: L10n.LiveActivity.Sample.Security.note,
                tag: "debug-security",
                title: "Security Alert",
                stages: [
                    .init(
                        message: "Motion detected at front door",
                        criticalText: "Motion",
                        icon: "mdi:motion-sensor",
                        color: "#FF9800"
                    ),
                    .init(
                        delay: 4,
                        message: "Person detected · Camera 1",
                        criticalText: "Person",
                        icon: "mdi:cctv",
                        color: "#F44336"
                    ),
                    .init(
                        delay: 4,
                        message: "Disarmed · All clear",
                        criticalText: "Safe",
                        icon: "mdi:shield-check",
                        color: "#4CAF50"
                    ),
                ]
            ),
            LiveActivitySample(
                id: "dishwasher",
                name: L10n.LiveActivity.Sample.Dishwasher.title,
                summary: L10n.LiveActivity.Sample.Dishwasher.summary,
                note: L10n.LiveActivity.Sample.Dishwasher.note,
                tag: "debug-dishwasher",
                title: "Dishwasher",
                stages: [
                    .init(
                        message: "Pre-wash in progress",
                        criticalText: "Pre-wash",
                        progress: 20,
                        progressMax: 100,
                        icon: "mdi:dishwasher",
                        color: "#26C6DA"
                    ),
                    .init(
                        delay: 3,
                        message: "Main wash · Hot cycle",
                        criticalText: "Wash",
                        progress: 50,
                        progressMax: 100,
                        icon: "mdi:dishwasher",
                        color: "#26C6DA"
                    ),
                    .init(
                        delay: 3,
                        message: "Rinse and dry",
                        criticalText: "Rinse",
                        progress: 80,
                        progressMax: 100,
                        icon: "mdi:dishwasher",
                        color: "#26C6DA"
                    ),
                    .init(
                        delay: 3,
                        message: "Dishes are clean",
                        criticalText: "Done",
                        progress: 100,
                        progressMax: 100,
                        icon: "mdi:check-circle",
                        color: "#4CAF50"
                    ),
                ],
                endsItself: true
            ),
            LiveActivitySample(
                id: "rate-limit",
                name: L10n.LiveActivity.Sample.RateLimit.title,
                summary: L10n.LiveActivity.Sample.RateLimit.summary,
                note: L10n.LiveActivity.Sample.RateLimit.note,
                tag: "debug-rapid",
                title: "Rate Limit Test",
                stages: [
                    .init(
                        message: "Update 1 of 6 · Watch for skipped values on device",
                        criticalText: "#1",
                        progress: 0,
                        progressMax: 100,
                        icon: "mdi:lightning-bolt",
                        color: "#FF9800"
                    ),
                    .init(
                        delay: 2,
                        message: "Update 2 of 6",
                        criticalText: "#2",
                        progress: 17,
                        progressMax: 100,
                        icon: "mdi:lightning-bolt",
                        color: "#FF9800"
                    ),
                    .init(
                        delay: 2,
                        message: "Update 3 of 6",
                        criticalText: "#3",
                        progress: 33,
                        progressMax: 100,
                        icon: "mdi:lightning-bolt",
                        color: "#FF9800"
                    ),
                    .init(
                        delay: 2,
                        message: "Update 4 of 6",
                        criticalText: "#4",
                        progress: 50,
                        progressMax: 100,
                        icon: "mdi:lightning-bolt",
                        color: "#FF9800"
                    ),
                    .init(
                        delay: 2,
                        message: "Update 5 of 6",
                        criticalText: "#5",
                        progress: 67,
                        progressMax: 100,
                        icon: "mdi:lightning-bolt",
                        color: "#FF9800"
                    ),
                    .init(
                        delay: 2,
                        message: "Update 6 of 6 · All done",
                        criticalText: "#6",
                        progress: 100,
                        progressMax: 100,
                        icon: "mdi:lightning-bolt",
                        color: "#FF9800"
                    ),
                ]
            ),
        ]
    }

    // MARK: - Start

    /// Starts a sample locally (in-process, `pushType: nil`) and drives it through its stages.
    /// Single-stage samples start and stay put; multi-stage ones self-update on their delays.
    private func start(_ sample: LiveActivitySample) {
        guard let first = sample.stages.first else { return }
        Task {
            let attributes = HALiveActivityAttributes(tag: sample.tag, title: sample.title)
            guard let activity = try? Activity<HALiveActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(
                    state: first.contentState(),
                    staleDate: Date().addingTimeInterval(30 * 60)
                ),
                pushType: nil
            ) else { return }
            await loadActivities()

            for stage in sample.stages.dropFirst() {
                try? await Task.sleep(nanoseconds: UInt64(stage.delay * 1_000_000_000))
                await activity.update(ActivityContent(
                    state: stage.contentState(),
                    staleDate: Date().addingTimeInterval(30 * 60)
                ))
                await loadActivities()
            }

            if sample.endsItself, let last = sample.stages.last {
                await activity.end(
                    ActivityContent(
                        state: last.contentState(),
                        staleDate: Date().addingTimeInterval(30 * 60)
                    ),
                    dismissalPolicy: .default
                )
                await loadActivities()
            }
        }
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

// MARK: - Sample model

@available(iOS 17.2, *)
private struct LiveActivitySample: Identifiable {
    /// One state in a sample's timeline. Single-stage samples have exactly one.
    struct Stage {
        /// Seconds to wait after the previous stage before applying this one. Ignored for the first stage.
        var delay: Double = 0
        var message: String
        var criticalText: String?
        var progress: Int?
        var progressMax: Int?
        /// Seconds remaining at the moment the stage is applied (maps to `when` + `when_relative: true`).
        /// `0` resolves to "now", which renders as an unbounded count-up timer. Negative counts up
        /// toward `|value|` seconds and freezes there (bounded count-up). `nil` = no timer.
        var countdownSeconds: Double?
        var icon: String?
        var color: String?
        var backgroundColor: String?
        var textColor: String?
        var progressBarColor: String?
        var progressBarDirection: String?

        func contentState() -> HALiveActivityAttributes.ContentState {
            // countdownEnd is relative to now so the local demo matches `when_relative: true`,
            // where each update means "seconds remaining" from the moment it is received.
            // Negative mirrors the handler's bounded count-up: anchor now, end at now + |value|.
            let now = Date()
            return HALiveActivityAttributes.ContentState(
                message: message,
                criticalText: criticalText,
                progress: progress,
                progressMax: progressMax,
                chronometer: countdownSeconds == nil ? nil : true,
                countdownEnd: countdownSeconds.map { now.addingTimeInterval(abs($0)) },
                chronometerStart: (countdownSeconds ?? 0) < 0 ? now : nil,
                icon: icon,
                color: color,
                backgroundColor: backgroundColor,
                textColor: textColor,
                progressBarColor: progressBarColor,
                progressBarDirection: progressBarDirection
            )
        }
    }

    /// Stable identifier for SwiftUI identity; not shown to the user.
    let id: String
    /// Localized display name, used as the row title and detail title.
    let name: String
    /// Localized short, non-technical one-liner shown as the row subtitle.
    let summary: String
    /// Localized one-line explanation shown under the Start button.
    let note: String
    let tag: String
    let title: String
    let stages: [Stage]
    /// When `true`, the sample calls `activity.end()` after the final stage (full lifecycle demo).
    var endsItself: Bool = false

    /// The exact `notify` payload that reproduces this sample from a Home Assistant automation.
    /// Single-stage samples render one action; multi-stage ones render a script `sequence`.
    var yaml: String {
        let service = "notify.mobile_app_<your_device>"

        func payload(_ stage: Stage, keyIndent: Int) -> [String] {
            let key = String(repeating: " ", count: keyIndent)
            let sub = String(repeating: " ", count: keyIndent + 2)
            var lines = [
                "\(key)message: \"\(stage.message)\"",
                "\(key)title: \"\(title)\"",
                "\(key)data:",
                "\(sub)tag: \(tag)",
                "\(sub)live_update: true",
            ]
            if let criticalText = stage.criticalText { lines.append("\(sub)critical_text: \"\(criticalText)\"") }
            if let progress = stage.progress { lines.append("\(sub)progress: \(progress)") }
            if let progressMax = stage.progressMax { lines.append("\(sub)progress_max: \(progressMax)") }
            if let countdownSeconds = stage.countdownSeconds {
                lines.append("\(sub)chronometer: true")
                lines.append("\(sub)when: \(Int(countdownSeconds))")
                lines.append("\(sub)when_relative: true")
            }
            if let icon = stage.icon { lines.append("\(sub)notification_icon: \"\(icon)\"") }
            if let color = stage.color { lines.append("\(sub)notification_icon_color: \"\(color)\"") }
            if let backgroundColor = stage.backgroundColor {
                lines.append("\(sub)background_color: \"\(backgroundColor)\"")
            }
            if let textColor = stage.textColor { lines.append("\(sub)text_color: \"\(textColor)\"") }
            if let progressBarColor = stage.progressBarColor {
                lines.append("\(sub)progress_bar_color: \"\(progressBarColor)\"")
            }
            if let progressBarDirection = stage.progressBarDirection {
                lines.append("\(sub)progress_bar_direction: \"\(progressBarDirection)\"")
            }
            return lines
        }

        guard stages.count > 1 || endsItself else {
            return (["action: \(service)", "data:"] + payload(stages[0], keyIndent: 2))
                .joined(separator: "\n")
        }

        var lines = [
            "# Run as a Script. Each step targets the same tag, so it updates one Live Activity.",
            "sequence:",
        ]
        for (index, stage) in stages.enumerated() {
            if index > 0 {
                lines.append("  - delay: { seconds: \(Int(stage.delay)) }")
            }
            lines.append("  - action: \(service)")
            lines.append("    data:")
            lines += payload(stage, keyIndent: 6)
        }
        if endsItself {
            lines.append("  - delay: { seconds: 3 }")
            lines.append("  # clear_notification with the same tag ends the Live Activity.")
            lines.append("  - action: \(service)")
            lines.append("    data:")
            lines.append("      message: clear_notification")
            lines.append("      data:")
            lines.append("        tag: \(tag)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Sample detail

@available(iOS 17.2, *)
private struct LiveActivitySampleDetailView: View {
    let sample: LiveActivitySample
    let onStart: (LiveActivitySample) -> Void

    @State private var didStart = false

    var body: some View {
        List {
            Section {
                Button {
                    onStart(sample)
                    didStart = true
                } label: {
                    Label(L10n.LiveActivity.Samples.start, systemSymbol: .playFill)
                }

                if didStart {
                    Label(L10n.LiveActivity.Samples.started, systemSymbol: .checkmarkCircleFill)
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            } footer: {
                Text(sample.note)
            }

            Section {
                NavigationLink {
                    LiveActivityYAMLView(yaml: sample.yaml)
                } label: {
                    Label(L10n.LiveActivity.Samples.showYaml, systemSymbol: .curlybraces)
                }
            } footer: {
                Text(L10n.LiveActivity.Samples.detailFooter)
            }
        }
        .navigationTitle(sample.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - YAML viewer

@available(iOS 17.2, *)
private struct LiveActivityYAMLView: View {
    let yaml: String

    @State private var didCopy = false

    var body: some View {
        ScrollView(.vertical) {
            Text(YAMLSyntaxHighlighter.highlight(yaml))
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .navigationTitle(L10n.LiveActivity.Samples.yamlTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = yaml
                    withAnimation { didCopy = true }
                } label: {
                    Label(
                        didCopy ? L10n.LiveActivity.Samples.copied : L10n.LiveActivity.Samples.copy,
                        systemSymbol: didCopy ? .checkmark : .docOnDoc
                    )
                }
            }
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

#if os(iOS) && !targetEnvironment(macCatalyst)
@available(iOS 17.2, *)
extension LiveActivitySettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.LiveActivity.FrequentUpdates.title),
            SettingsSearchEntry(L10n.LiveActivity.Section.active),
            SettingsSearchEntry(L10n.LiveActivity.EndAll.button),
            SettingsSearchEntry(L10n.LiveActivity.Sync.button),
            SettingsSearchEntry(L10n.LiveActivity.Samples.title),
        ]
    }
}
#endif
