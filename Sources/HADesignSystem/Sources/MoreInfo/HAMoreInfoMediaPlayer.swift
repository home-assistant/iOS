#if !os(watchOS)
import HAIconic
import SwiftUI

/// A media player's more-info dialog: the artwork, what is playing, the track position, the
/// transport, the volume and a row of round buttons for browsing, grouping, source, sound mode and
/// power. The SwiftUI counterpart of the frontend's `more-info-media_player`.
///
/// The artwork is a resolved `Image`, as ``HAPictureCard`` takes one: the package fetches nothing.
public struct HAMoreInfoMediaPlayer: View {
    /// What repeat is set to, and so which glyph its button shows.
    public enum RepeatMode: String, CaseIterable, Sendable {
        case off
        case all
        case one
    }

    @Environment(\.locale) private var locale
    private let state: String
    private let artwork: Image?
    private let isPlaying: Bool
    private let title: String?
    private let artist: String?
    private let duration: Double?
    private let canSeek: Bool
    private let onPlayPause: (() -> Void)?
    private let onStop: (() -> Void)?
    private let onPrevious: (() -> Void)?
    private let onNext: (() -> Void)?
    private let shuffle: Binding<Bool>?
    private let repeatMode: Binding<RepeatMode>?
    private let volume: Binding<Double>?
    private let isMuted: Binding<Bool>?
    private let onVolumeDown: (() -> Void)?
    private let onVolumeUp: (() -> Void)?
    private let commands: [HAMoreInfoCommand]
    private let selects: [HAMoreInfoSelect]
    private let isUnavailable: Bool
    @Binding private var position: Double

    /// - Parameters:
    ///   - state: Written in the artwork's place when there is nothing to show: "Off", "Unavailable".
    ///   - position: Seconds into the track, with `duration` the track's length. No bar without a
    ///     duration.
    ///   - onPlayPause: The big centre button; `onStop` takes its place for a player that only stops.
    ///   - volume: 0–1, for a player that sets its volume; `onVolumeDown` and `onVolumeUp` for one
    ///     that only steps it.
    ///   - commands: Browse media, join and power, as supported, in the bottom row.
    ///   - selects: Source and sound mode, as round buttons opening a menu in the same row.
    public init(
        state: String,
        artwork: Image? = nil,
        isPlaying: Bool = false,
        title: String? = nil,
        artist: String? = nil,
        position: Binding<Double> = .constant(0),
        duration: Double? = nil,
        canSeek: Bool = true,
        onPlayPause: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil,
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        shuffle: Binding<Bool>? = nil,
        repeatMode: Binding<RepeatMode>? = nil,
        volume: Binding<Double>? = nil,
        isMuted: Binding<Bool>? = nil,
        onVolumeDown: (() -> Void)? = nil,
        onVolumeUp: (() -> Void)? = nil,
        commands: [HAMoreInfoCommand] = [],
        selects: [HAMoreInfoSelect] = [],
        isUnavailable: Bool = false
    ) {
        self.state = state
        self.artwork = artwork
        self.isPlaying = isPlaying
        self.title = title
        self.artist = artist
        _position = position
        self.duration = duration
        self.canSeek = canSeek
        self.onPlayPause = onPlayPause
        self.onStop = onStop
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.shuffle = shuffle
        self.repeatMode = repeatMode
        self.volume = volume
        self.isMuted = isMuted
        self.onVolumeDown = onVolumeDown
        self.onVolumeUp = onVolumeUp
        self.commands = commands
        self.selects = selects
        self.isUnavailable = isUnavailable
    }

    private var strings: HADesignSystemEnvironment.Strings { HADesignSystemEnvironment.current.strings }
    private var artworkSize: CGFloat { isPlaying ? DesignSystem.StateControl.dialDiameter : 240 }

    private var repeatIcon: MaterialDesignIcons {
        switch repeatMode?.wrappedValue ?? .off {
        case .off: .repeatOffIcon
        case .all: .repeatIcon
        case .one: .repeatOnceIcon
        }
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            Group {
                if let artwork, !isUnavailable {
                    artwork
                        .resizable()
                        .scaledToFill()
                        .frame(width: artworkSize, height: artworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .accessibilityLabel(Text(title ?? state))
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half)
                        .fill(Color.haSecondaryBackground)
                        .frame(width: 240, height: 240)
                        .overlay {
                            if isUnavailable {
                                Text(state)
                                    .font(.title3)
                            } else {
                                MaterialDesignIconsImage(icon: .musicNoteIcon, size: 36)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text(state))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240)

            if !isUnavailable {
                if title != nil || artist != nil {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        if let title {
                            HAMarqueeText(title)
                                .font(.system(size: 20, weight: .bold))
                        }
                        if let artist {
                            HAMarqueeText(artist)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spaces.one)
                }

                if let duration, duration > 0 {
                    VStack(spacing: DesignSystem.Spaces.one) {
                        Slider(value: $position, in: 0 ... duration, step: 1)
                            .tint(.haPrimary)
                            .disabled(!canSeek)
                            .accessibilityLabel(Text(strings.trackPosition))
                        HStack {
                            Text(Self.formatted(position))
                            Spacer()
                            Text(Self.formatted(duration))
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }

                VStack(spacing: DesignSystem.Spaces.three) {
                    transport
                    volumeRow
                    if !commands.isEmpty || !selects.isEmpty {
                        HStack {
                            ForEach(commands) { command in
                                roundButton(command.icon, label: command.label, isDisabled: command.isDisabled) {
                                    command.action()
                                }
                                .frame(maxWidth: .infinity)
                            }
                            ForEach(selects) { select in
                                Menu {
                                    Picker(select.label, selection: select.selection) {
                                        ForEach(select.options) { option in
                                            Text(option.label).tag(Optional(option.id))
                                        }
                                    }
                                } label: {
                                    roundIcon(select.icon)
                                }
                                .buttonStyle(.plain)
                                .disabled(select.isDisabled)
                                .accessibilityLabel(Text(select.label))
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(maxWidth: DesignSystem.StateControl.length)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var transport: some View {
        if onPlayPause != nil || onStop != nil || onPrevious != nil || onNext != nil {
            HStack {
                if let repeatMode {
                    plainButton(repeatIcon, label: strings.repeatMode) {
                        let modes = RepeatMode.allCases
                        let next = modes.firstIndex(of: repeatMode.wrappedValue).map { ($0 + 1) % modes.count } ?? 0
                        repeatMode.wrappedValue = modes[next]
                    }
                } else {
                    Color.clear.frame(width: 48, height: 48)
                }
                Spacer()
                if let onPrevious {
                    plainButton(.skipPreviousIcon, label: strings.previousTrack, action: onPrevious)
                } else {
                    Color.clear.frame(width: 48, height: 48)
                }
                Spacer()
                if let action = onPlayPause ?? onStop {
                    Button(action: action) {
                        MaterialDesignIconsImage(
                            icon: onPlayPause == nil ? .stopIcon : isPlaying ? .pauseIcon : .playIcon,
                            size: 24
                        )
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 56)
                        .background(Capsule().fill(Color.haPrimary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(
                        onPlayPause == nil ? strings.stop : isPlaying ? strings.pause : strings
                            .play
                    ))
                }
                Spacer()
                if let onNext {
                    plainButton(.skipNextIcon, label: strings.nextTrack, action: onNext)
                } else {
                    Color.clear.frame(width: 48, height: 48)
                }
                Spacer()
                if let shuffle {
                    plainButton(shuffle.wrappedValue ? .shuffleIcon : .shuffleDisabledIcon, label: strings.shuffle) {
                        shuffle.wrappedValue.toggle()
                    }
                } else {
                    Color.clear.frame(width: 48, height: 48)
                }
            }
        }
    }

    @ViewBuilder
    private var volumeRow: some View {
        if volume != nil || onVolumeDown != nil || onVolumeUp != nil {
            HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                if let isMuted {
                    plainButton(
                        isMuted.wrappedValue ? .volumeOffIcon : .volumeHighIcon,
                        label: isMuted.wrappedValue ? strings.unmute : strings.mute
                    ) {
                        isMuted.wrappedValue.toggle()
                    }
                } else if volume != nil {
                    MaterialDesignIconsImage(icon: .volumeHighIcon, size: 24)
                        .foregroundStyle(.secondary)
                }
                if let volume {
                    Slider(value: volume, in: 0 ... 1)
                        .tint(.haPrimary)
                        .accessibilityLabel(Text(strings.volume))
                } else {
                    if let onVolumeDown {
                        plainButton(.volumeMinusIcon, label: strings.volumeDown, action: onVolumeDown)
                    }
                    if let onVolumeUp {
                        plainButton(.volumePlusIcon, label: strings.volumeUp, action: onVolumeUp)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.one)
        }
    }

    private func plainButton(_ icon: MaterialDesignIcons, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MaterialDesignIconsImage(icon: icon, size: 24)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private func roundButton(
        _ icon: MaterialDesignIcons,
        label: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            roundIcon(icon)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(Text(label))
    }

    private func roundIcon(_ icon: MaterialDesignIcons) -> some View {
        MaterialDesignIconsImage(icon: icon, size: 24)
            .foregroundStyle(.secondary)
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.haNeutralQuietFill))
    }

    /// `formatMediaTime`: minutes and seconds, with hours only once there are any.
    static func formatted(_ seconds: Double) -> String {
        let total = Int(Swift.max(seconds, 0))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }
}

#Preview {
    ScrollView {
        HAMoreInfoMediaPlayer(
            state: "Playing",
            isPlaying: true,
            title: "Epic sax guy 10 hours",
            artist: "YouTube",
            position: .constant(1840),
            duration: 36000,
            onPlayPause: {},
            onPrevious: {},
            onNext: {},
            shuffle: .constant(false),
            repeatMode: .constant(.all),
            volume: .constant(0.6),
            isMuted: .constant(false),
            commands: [
                HAMoreInfoCommand(id: "browse", icon: .playBoxMultipleIcon, label: "Browse media") {},
                HAMoreInfoCommand(id: "off", icon: .powerIcon, label: "Turn off") {},
            ],
            selects: [
                HAMoreInfoSelect(
                    id: "source",
                    label: "Source",
                    icon: .loginVariantIcon,
                    options: [.init(id: "tv", label: "TV")],
                    selection: .constant("tv")
                ),
            ]
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoMediaPlayer: FrontendComponent {
    public static var frontendComponentName: String { "more-info-media_player" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
