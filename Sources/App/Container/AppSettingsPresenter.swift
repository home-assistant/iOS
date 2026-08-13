import Shared
import SwiftUI

/// Drives app Settings presentation from above the kiosk/container swap (hosted by `ConditionalContainerView`)
/// so that toggling kiosk mode — reachable via Settings → Kiosk — doesn't tear Settings down with the
/// container it would otherwise be presented from. Settings requested by the frontend external bus is pushed
/// onto the container's navigation stack; every other entry point (gestures, empty state, …) uses a sheet.
/// On Catalyst it opens in its own scene.
///
/// The same sheet is also the server picker: at the medium detent the servers cover Settings as buttons that
/// activate them, and expanding uncovers Settings as usual. The two swap freely in both directions — Settings
/// stays mounted underneath, so collapsing and expanding again lands back on whatever screen it had pushed.
final class AppSettingsPresenter: ObservableObject {
    /// What the settings sheet shows. `serverSelection` is the compact, medium-detent content; `full` is the
    /// regular Settings screen.
    enum Mode {
        case serverSelection
        case full
    }

    /// A pending "pick a server" request (deep link, notification, gesture, empty state). `onSelect` runs when
    /// the user activates a server from the compact sheet, and is dropped when the sheet goes away instead.
    struct ServerSelectionRequest {
        let prompt: String?
        /// Only the stand-by view has something for the sheet to zoom out of; every other entry point gets the
        /// regular slide-up.
        let zoomsFromStandBy: Bool
        let onSelect: (Server) -> Void
    }

    static let shared = AppSettingsPresenter()

    @Published var isSheetPresented = false
    @Published var isPushPresented = false
    @Published private(set) var mode: Mode = .full
    /// Whether Settings is mounted behind the picker. It stays mounted once shown so that its navigation
    /// survives a collapse back to the picker; a sheet opened straight on the picker doesn't pay for it until
    /// the user asks for Settings.
    @Published private(set) var isFullSettingsMounted = true
    @Published var detent: PresentationDetent = .large
    private(set) var selectionRequest: ServerSelectionRequest?

    private init() {}

    /// Opens the sheet on Settings itself.
    func presentSettings() {
        selectionRequest = nil
        mode = .full
        isFullSettingsMounted = true
        detent = .large
        isSheetPresented = true
    }

    /// Opens the sheet on the compact server picker. With a single server there is nothing to pick, so the
    /// request is dropped and Settings opens instead — callers that need a choice (deep links) only ask for
    /// one when there is more than one server.
    func presentServerSelection(_ request: ServerSelectionRequest) {
        guard Current.servers.all.count > 1 else {
            presentSettings()
            return
        }
        selectionRequest = request
        mode = .serverSelection
        isFullSettingsMounted = false
        detent = .medium
        isSheetPresented = true
    }

    /// Uncovers Settings, either because the sheet was expanded or because the picker's own Settings row was
    /// tapped. On Catalyst — where the sheet has no detents to drag — Settings is its own scene instead.
    /// The pending request is kept: collapsing back to the picker can still complete it.
    func showFullSettings() {
        if Current.isCatalyst, Current.sceneManager.supportsMultipleScenes {
            isSheetPresented = false
            Current.sceneManager.activateAnyScene(for: .settings)
            return
        }
        mode = .full
        isFullSettingsMounted = true
        detent = .large
    }

    /// Covers Settings with the picker again, following the sheet back down to the medium detent.
    func showServerSelection() {
        mode = .serverSelection
        detent = .medium
    }

    /// Hands the picked server to whoever asked for the selection, defaulting to activating it (the sheet can
    /// also be dragged down onto the picker without a request behind it).
    func completeServerSelection(_ server: Server) {
        // The request stays put until the sheet has actually gone: it carries the transition the dismissal
        // animates back into, and clearing it here would drop that mid-animation. `sheetDismissed()` picks
        // it up afterwards.
        let request = selectionRequest
        isSheetPresented = false

        if let request {
            request.onSelect(server)
        } else {
            Current.sceneManager.appCoordinator.done { coordinator in
                coordinator.activate(server: server)
            }
        }
    }

    /// Resets the sheet so the next presentation starts from a known state. A request still pending here means
    /// the user dismissed the sheet instead of picking, so it is dropped rather than left to fire later.
    func sheetDismissed() {
        // SwiftUI reports the dismissal once the animation ends, which can land after the sheet has already
        // been asked to come back (a deep link clearing the screen before presenting the picker). Anything
        // set up in the meantime is left alone.
        guard !isSheetPresented else { return }
        selectionRequest = nil
        mode = .full
        isFullSettingsMounted = true
        detent = .large
    }
}
