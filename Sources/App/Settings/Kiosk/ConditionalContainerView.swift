import HADesignSystem
import Shared
import SwiftUI

struct ConditionalContainerView: View {
    @StateObject private var kiosk = Current.kiosk
    @ObservedObject private var appSettings = AppSettingsPresenter.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showKioskSettings = false
    @Namespace private var serverSelectionNamespace

    // The navigation stack Settings is pushed onto lives in `ContainerView`, around the frontend alone:
    // it is the only screen anything is ever pushed over, and a stack here would also enclose
    // onboarding's own — two nested `NavigationStack`s crash SwiftUI on iOS 16.
    var body: some View {
        content
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
                } else if #available(iOS 18.0, *), let sourceID = appSettings.zoomSourceID {
                    view.navigationTransition(.zoom(sourceID: sourceID, in: serverSelectionNamespace))
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
