#if !os(watchOS)
import HAIconic
import SwiftUI

/// An update's more-info dialog: the entity's row, the install progress, the installed and latest
/// versions, the release notes and, at the bottom, the backup switch with skip and install. The
/// SwiftUI counterpart of the frontend's `more-info-update`, under its `state-card-content`.
public struct HAMoreInfoUpdate: View {
    /// The "Create backup" switch, for an update supporting `BACKUP`.
    public struct Backup {
        public let title: String
        public let description: String?
        public let isOn: Binding<Bool>

        public init(title: String, description: String? = nil, isOn: Binding<Bool>) {
            self.title = title
            self.description = description
            self.isOn = isOn
        }
    }

    /// One labelled version, as the frontend lays out `installed_version` and `latest_version`.
    public struct Version: Hashable {
        public let label: String
        public let value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    private let name: String
    private let icon: MaterialDesignIcons
    private let color: Color
    private let lastChanged: Date
    private let now: Date
    private let state: String
    private let title: String?
    private let versions: [Version]
    private let releaseURL: URL?
    private let releaseNotes: String?
    private let error: String?
    private let isInstalling: Bool
    private let progress: Double?
    private let backup: Backup?
    private let isSkipped: Bool
    private let canSkip: Bool
    private let canInstall: Bool
    private let onSkip: () -> Void
    private let onClearSkipped: () -> Void
    private let onInstall: (() -> Void)?

    /// - Parameters:
    ///   - state: The row's trailing text: "Update available", "Up-to-date".
    ///   - versions: Installed and latest, each with its label; "Unavailable" when unknown.
    ///   - releaseNotes: Markdown, from the release notes or else the release summary.
    ///   - progress: 0–100 while installing with progress reported; `nil` with `isInstalling` draws
    ///     the indeterminate bar.
    ///   - isSkipped: The latest version was skipped, so the button undoes the skip instead.
    ///   - onInstall: Adds the install button, for an update supporting `INSTALL`.
    public init(
        name: String,
        icon: MaterialDesignIcons = .packageUpIcon,
        color: Color = FrontendColors.stateUpdateActiveColor.color,
        lastChanged: Date,
        now: Date,
        state: String,
        title: String? = nil,
        versions: [Version],
        releaseURL: URL? = nil,
        releaseNotes: String? = nil,
        error: String? = nil,
        isInstalling: Bool = false,
        progress: Double? = nil,
        backup: Backup? = nil,
        isSkipped: Bool = false,
        canSkip: Bool = true,
        canInstall: Bool = true,
        onSkip: @escaping () -> Void,
        onClearSkipped: @escaping () -> Void,
        onInstall: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.lastChanged = lastChanged
        self.now = now
        self.state = state
        self.title = title
        self.versions = versions
        self.releaseURL = releaseURL
        self.releaseNotes = releaseNotes
        self.error = error
        self.isInstalling = isInstalling
        self.progress = progress
        self.backup = backup
        self.isSkipped = isSkipped
        self.canSkip = canSkip
        self.canInstall = canInstall
        self.onSkip = onSkip
        self.onClearSkipped = onClearSkipped
        self.onInstall = onInstall
    }

    private var strings: HADesignSystemEnvironment.Strings { HADesignSystemEnvironment.current.strings }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            HAMoreInfoStateCard(name: name, icon: icon, color: color, lastChanged: lastChanged, now: now) {
                Text(state)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                if isInstalling {
                    HAProgressBar(value: progress.map { $0 / 100 })
                }
                if let title {
                    Text(title)
                        .font(.headline)
                }
                if let error {
                    HAAlertView(error, alertType: .error)
                }
                ForEach(versions, id: \.self) { version in
                    HStack {
                        Text(version.label)
                        Spacer()
                        Text(version.value)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.system(size: 14))
                }
                if let releaseURL {
                    Link(strings.updateReleaseAnnouncement, destination: releaseURL)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.haPrimary)
                }
            }
            if let releaseNotes, error == nil {
                Divider()
                HAMarkdownText(releaseNotes)
            }
            Divider()
            if let backup {
                Toggle(isOn: backup.isOn) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                        Text(backup.title)
                        if let description = backup.description {
                            Text(description)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.haPrimary)
                .disabled(isInstalling)
            }
            HStack(spacing: DesignSystem.Spaces.one) {
                Spacer()
                if isSkipped {
                    Button(strings.updateClearSkipped, action: onClearSkipped)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.haPrimary)
                } else {
                    Button(strings.updateSkip, action: onSkip)
                        .buttonStyle(.plain)
                        .foregroundStyle(canSkip && !isInstalling ? Color.haPrimary : Color.secondary)
                        .disabled(!canSkip || isInstalling)
                }
                if let onInstall {
                    Button(action: onInstall) {
                        HStack(spacing: DesignSystem.Spaces.one) {
                            if isInstalling {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(strings.updateInstall)
                        }
                    }
                    .buttonStyle(.primaryButton)
                    .fixedSize()
                    .disabled(!canInstall || isInstalling)
                }
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, DesignSystem.Spaces.one)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.four) {
            HAMoreInfoUpdate(
                name: "Home Assistant Core",
                lastChanged: Date(timeIntervalSinceNow: -22),
                now: Date(),
                state: "Update available",
                title: "Home Assistant Core",
                versions: [
                    .init(label: "Installed version", value: "2026.10.1"),
                    .init(label: "Latest version", value: "2026.10.2"),
                ],
                releaseNotes: "## What's new\n- Faster startup\n- Bug fixes",
                backup: .init(title: "Create backup", description: "Before updating", isOn: .constant(true)),
                onSkip: {},
                onClearSkipped: {},
                onInstall: {}
            )
            HAMoreInfoUpdate(
                name: "With 50 in_progress",
                lastChanged: Date(timeIntervalSinceNow: -2280),
                now: Date(),
                state: "Installing (50%)",
                versions: [
                    .init(label: "Installed version", value: "1.0.0"),
                    .init(label: "Latest version", value: "1.0.1"),
                ],
                isInstalling: true,
                progress: 50,
                onSkip: {},
                onClearSkipped: {},
                onInstall: {}
            )
        }
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoUpdate: FrontendComponent {
    public static var frontendComponentName: String { "more-info-update" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
