#if !os(watchOS)
import HAIconic
import SwiftUI

/// A full-screen loader layered on top of content that is still getting ready (e.g. the web frontend):
/// a translucent blur that keeps the content visible behind it, with a logo and the branded spinner
/// centered. The whole view blurs in on appear. After `controlsRevealDelay` seconds, escape hatches
/// fade in: a settings button (top leading) and a retry button (bottom).
public struct FullScreenLoaderView: View {
    let logo: Image
    let retryTitle: String
    let controlsRevealDelay: TimeInterval
    let settingsAction: () -> Void
    let retryAction: () -> Void

    @State private var hasAppeared = false
    @State private var showsDelayedControls = false

    public init(
        logo: Image,
        retryTitle: String,
        controlsRevealDelay: TimeInterval = 5,
        settingsAction: @escaping () -> Void,
        retryAction: @escaping () -> Void
    ) {
        self.logo = logo
        self.retryTitle = retryTitle
        self.controlsRevealDelay = controlsRevealDelay
        self.settingsAction = settingsAction
        self.retryAction = retryAction
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: DesignSystem.Spaces.five) {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                HAProgressView()
            }
            if showsDelayedControls {
                Group {
                    if #available(iOS 26.0, *) {
                        SettingsButton(action: settingsAction)
                            .padding(DesignSystem.Spaces.one)
                            .glassEffect(.regular.interactive(), in: Circle())
                    } else {
                        SettingsButton(action: settingsAction)
                            .padding(DesignSystem.Spaces.one)
                            .background(.regularMaterial, in: Circle())
                    }
                }
                .padding(DesignSystem.Spaces.two)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
                Button(retryTitle, action: retryAction)
                    .buttonStyle(.primaryButton)
                    .padding(.horizontal, DesignSystem.Spaces.two)
                    .padding(.bottom, DesignSystem.Spaces.two)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(DesignSystem.Animation.default, value: showsDelayedControls)
        .onAppear {
            withAnimation(DesignSystem.Animation.default) {
                hasAppeared = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(controlsRevealDelay))
            showsDelayedControls = true
        }
    }
}

/// Preview-only stand-in for the web frontend: a grid of Home Assistant-style dashboard tiles,
/// so the previews show how the loader's blur reads over real-looking content.
private struct FullScreenLoaderPreviewDashboard: View {
    private let tiles: [(icon: String, color: Color, name: String, state: String)] = [
        ("lightbulb.fill", .yellow, "Living Room", "On"),
        ("thermometer.medium", .orange, "Thermostat", "21.5℃"),
        ("lock.fill", .green, "Front Door", "Locked"),
        ("video.fill", .blue, "Doorbell", "Idle"),
        ("speaker.wave.2.fill", .purple, "Speaker", "Playing"),
        ("fan.fill", .teal, "Bedroom Fan", "Off"),
        ("blinds.horizontal.closed", .brown, "Blinds", "Closed"),
        ("bolt.fill", .red, "Energy", "1.2 kW"),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: DesignSystem.Spaces.oneAndHalf
            ) {
                ForEach(tiles, id: \.name) { tile in
                    HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                        Image(systemName: tile.icon)
                            .foregroundStyle(tile.color)
                            .frame(width: 36, height: 36)
                            .background(tile.color.opacity(0.2))
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(tile.name)
                                .font(DesignSystem.Font.footnote.bold())
                            Text(tile.state)
                                .font(DesignSystem.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(DesignSystem.Spaces.oneAndHalf)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

#Preview("Over content") {
    MaterialDesignIcons.register()
    return ZStack {
        FullScreenLoaderPreviewDashboard()
        FullScreenLoaderView(
            logo: Image(systemName: "house.fill"),
            retryTitle: "Retry",
            settingsAction: {},
            retryAction: {}
        )
    }
}

#Preview("Controls revealed") {
    MaterialDesignIcons.register()
    return ZStack {
        FullScreenLoaderPreviewDashboard()
        FullScreenLoaderView(
            logo: Image(systemName: "house.fill"),
            retryTitle: "Retry",
            controlsRevealDelay: 0,
            settingsAction: {},
            retryAction: {}
        )
    }
}

/// Preview-only harness with a button to toggle the loader on and off, to inspect its blur-in
/// transition over the mock dashboard.
private struct FullScreenLoaderPreviewToggleHarness: View {
    @State private var showsLoader = false

    var body: some View {
        ZStack {
            FullScreenLoaderPreviewDashboard()
            if showsLoader {
                FullScreenLoaderView(
                    logo: Image(systemName: "house.fill"),
                    retryTitle: "Retry",
                    settingsAction: {},
                    retryAction: {}
                )
                .transition(.opacity)
            }
            Button(showsLoader ? "Hide loader" : "Show loader") {
                withAnimation(DesignSystem.Animation.default) {
                    showsLoader.toggle()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(DesignSystem.Spaces.two)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

#Preview("Toggle visibility (debug)") {
    MaterialDesignIcons.register()
    return FullScreenLoaderPreviewToggleHarness()
}
#endif
