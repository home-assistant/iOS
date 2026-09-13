import Foundation

/// A part of the Home Assistant web frontend that kiosk mode can hide.
///
/// The raw values are the element names the frontend's `kiosk_mode/set` external bus command
/// understands, so they must stay in step with `KIOSK_ELEMENTS` in the frontend repository.
public enum KioskFrontendElement: String, Codable, CaseIterable, Identifiable {
    /// The sidebar itself: never docked, only reachable as an overlay.
    case sidebar
    /// The hamburger button that opens the sidebar, in every panel's toolbar.
    case sidebarButton = "sidebar_button"
    /// The dashboard view tabs. The current view's title is shown instead.
    case dashboardTabs = "dashboard_tabs"
    /// The "+" menu that adds a device, automation, area or person.
    case dashboardAddButton = "dashboard_add_button"
    /// The search button that opens the quick bar.
    case dashboardSearchButton = "dashboard_search_button"
    /// The Assist button.
    case dashboardAssistButton = "dashboard_assist_button"
    /// The pencil that switches the dashboard into edit mode.
    case dashboardEditButton = "dashboard_edit_button"
    /// The header the frontend draws above an ingress add-on page.
    case appPanelHeader = "app_panel_header"

    public var id: String { rawValue }

    /// What "Hide sidebar and top bar controls" hid back when it was a single switch, and what a
    /// frontend too old to understand the element list still hides. Keeping this as the default
    /// means turning that switch on looks the same as it always did until the user says otherwise.
    public static let defaultHidden: Set<KioskFrontendElement> = [
        .sidebar,
        .sidebarButton,
        .dashboardAddButton,
        .dashboardSearchButton,
        .dashboardEditButton,
        .appPanelHeader,
    ]
}
