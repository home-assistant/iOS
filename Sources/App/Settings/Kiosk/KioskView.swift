import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

struct ConditionalContainerView: View {
    @StateObject private var kiosk = Current.kiosk
    @ObservedObject private var appSettings = AppSettingsPresenter.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showKioskSettings = false
    @Namespace private var serverSelectionNamespace

    var body: some View {
        // The stack is always there, whatever the horizontal size class. Picking between a stack and bare
        // `content` with an `if` gave the two branches different structural identities, so every size-class
        // change (a Plus/Max/Air-sized iPhone rotating, an iPad entering or leaving Split View) tore the
        // frontend down and rebuilt it: a fresh `WebViewController`, a full page reload and the user dropped
        // back on the default dashboard. Whether Settings pushes onto this stack or opens as a sheet is still
        // decided per presentation, from the window's size class at that moment (see `ContainerView`); in
        // regular width the path simply stays empty and the stack is inert.
        //
        // Driven entirely by `appSettings.pushPath` so Settings and the screens it pushes share one
        // value-based mechanism: the boolean `navigationDestination(isPresented:)` used here before
        // made SwiftUI push Settings again in place of the screen that was tapped. The path is also
        // single-typed, because SwiftUI's path diffing fatally errors comparing elements of
        // different types at the same position: Settings' own pushes arrive wrapped as
        // `AppSettingsPushRoute.item` instead of raw `SettingsItem` values.
        NavigationStack(path: $appSettings.pushPath) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppSettingsPushRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView(embedInOwnNavigation: false)
                            .injectingViewControllerProvider()
                    case let .item(item):
                        item.destinationView
                            .injectingViewControllerProvider()
                    }
                }
        }
        .sheet(isPresented: $appSettings.isSheetPresented, onDismiss: appSettings.sheetDismissed) {
            settingsSheet
        }
    }

    /// One sheet, two sizes: the servers at the medium detent, Settings once it is expanded. Settings is
    /// hidden rather than torn down while the picker is up — list backgrounds are transparent inside a sheet,
    /// so nothing "covers" anything here, and rebuilding it would throw away any screen it had pushed.
    @ViewBuilder
    private var settingsSheet: some View {
        ZStack {
            if appSettings.isFullSettingsMounted {
                let isCovered = appSettings.mode == .serverSelection
                SettingsView()
                    .opacity(isCovered ? 0 : 1)
                    .allowsHitTesting(!isCovered)
                    .accessibilityHidden(isCovered)
            }
            if appSettings.mode == .serverSelection {
                // Backstop for the hidden Settings layer: its navigation bar is UIKit-backed and doesn't
                // always take the opacity above with it.
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                    .transition(.opacity)
                ServerSelectionListView(
                    prompt: appSettings.selectionRequest?.prompt,
                    selectAction: appSettings.completeServerSelection,
                    expandAction: {
                        withAnimation(DesignSystem.Animation.easeInOutFaster) {
                            appSettings.showFullSettings()
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .injectingViewControllerProvider()
        #if !targetEnvironment(macCatalyst)
            .presentationDetents(sheetDetents, selection: $appSettings.detent)
            .presentationDragIndicator(offersCompactDetent ? .visible : .automatic)
            .modify { view in
                if #available(iOS 18.0, *), appSettings.selectionRequest?.zoomsFromStandBy == true {
                    view.navigationTransition(.zoom(
                        sourceID: HomeAssistantStandByView.serverSelectionTransitionID,
                        in: serverSelectionNamespace
                    ))
                } else {
                    view
                }
            }
            .onChange(of: appSettings.detent) { detent in
                // The detent is what picks the content: all the way up is Settings, back down is the picker.
                withAnimation(DesignSystem.Animation.easeInOutFaster) {
                    if detent == .large {
                        appSettings.showFullSettings()
                    } else {
                        appSettings.showServerSelection()
                    }
                }
            }
        #endif
    }

    /// A sheet showing the picker keeps its detent whatever the servers do; one opened on Settings only offers
    /// to shrink into the picker when there is more than one server to switch between.
    private var offersCompactDetent: Bool {
        appSettings.mode == .serverSelection || Current.servers.all.count > 1
    }

    private var sheetDetents: Set<PresentationDetent> {
        offersCompactDetent ? [.medium, .large] : [.large]
    }

    private var content: some View {
        Group {
            if kiosk.settings.enabled {
                KioskView(showSettings: $showKioskSettings)
            } else {
                ContainerView()
            }
        }
        // The zoom transition into the server picker starts from the frontend's stand-by view, which is
        // several levels down from the sheet that plays it.
        .environment(\.serverSelectionNamespace, serverSelectionNamespace)
        .onAppear { applyKeepScreenOn() }
        .onChange(of: kiosk.shouldKeepScreenOn) { _ in applyKeepScreenOn() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { applyKeepScreenOn() }
        }
        .onChange(of: appSettings.isSheetPresented) { isPresented in
            refreshWebViewIfSettingsClosed(isPresented)
        }
        .onChange(of: appSettings.isPushPresented) { isPresented in
            refreshWebViewIfSettingsClosed(isPresented)
        }
        // Settings itself is cleared by `AppPresentationDismisser` (it lives in a shared presenter); the
        // kiosk settings sheet is view state, so it opts in here.
        .dismissesOnAppNavigation { showKioskSettings = false }
        .sheet(isPresented: $showKioskSettings) {
            NavigationView {
                KioskSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            CloseButton { showKioskSettings = false }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }

    private func applyKeepScreenOn() {
        UIApplication.shared.isIdleTimerDisabled = kiosk.shouldKeepScreenOn
    }

    private func refreshWebViewIfSettingsClosed(_ isPresented: Bool) {
        guard !isPresented else { return }
        Current.sceneManager.webViewControllerPromise.done { $0.refreshIfDisconnected() }
    }
}

struct KioskView: View {
    @StateObject private var screensaver = KioskScreensaverController()
    @StateObject private var kiosk = Current.kiosk
    @Binding var showSettings: Bool

    var body: some View {
        ContainerView()
            .background(KioskActivityDetector { screensaver.recordActivity() })
            .overlay(alignment: .bottomLeading) {
                if Current.isDebug {
                    debugWatermark
                }
            }
            .overlay {
                ZStack(alignment: settingsEntryAlignment) {
                    Color.clear
                        .allowsHitTesting(false)
                    settingsEntryButton
                        .padding(DesignSystem.Spaces.two)
                }
                .ignoresSafeArea()
            }
            .overlay {
                if screensaver.isActive {
                    KioskScreensaverView(settings: screensaver.screensaver) {
                        screensaver.wake()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: screensaver.isActive)
    }

    private var settingsEntryAlignment: Alignment {
        switch kiosk.settings.settingsEntryPosition {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    private var settingsEntryButton: some View {
        Button {
            showSettings = true
        } label: {
            KioskSettingsEntryIcon(
                backgroundColor: Color(
                    hex: kiosk.settings.settingsEntryBackgroundColor ?? KioskSettingsEntryIcon
                        .defaultBackgroundColorHex
                ),
                iconColor: Color(
                    hex: kiosk.settings.settingsEntryIconColor ?? KioskSettingsEntryIcon
                        .defaultIconColorHex
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Kiosk.title)
    }

    private var debugWatermark: some View {
        Text(verbatim: "KIOSK MODE")
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spaces.one)
            .padding(.vertical, DesignSystem.Spaces.half)
            .background(Color.red.opacity(0.75))
            .clipShape(Capsule())
            .padding(DesignSystem.Spaces.two)
            .allowsHitTesting(false)
    }
}

struct KioskSettingsEntryIcon: View {
    static let defaultBackgroundColorHex = "000000"
    static let defaultIconColorHex = "FFFFFF"

    var backgroundColor: Color
    var iconColor: Color

    var body: some View {
        Image(systemSymbol: .gearshapeFill)
            .font(.body)
            .foregroundStyle(iconColor)
            .padding(DesignSystem.Spaces.one)
            .background(backgroundColor)
            .clipShape(.circle)
    }
}
