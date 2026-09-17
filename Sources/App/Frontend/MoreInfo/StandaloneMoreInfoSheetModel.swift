import Combine
import Foundation

/// What the standalone more-info sheet's chrome shows: the frontend header's title, breadcrumb,
/// buttons and menu, and whether the page is still booting behind the native loader.
///
/// The title and subtitle first come with `more_info/open`, so the bar is right from the first
/// frame; everything else, and every later change, comes with `more_info/header` from the sheet's
/// own frontend (see `StandaloneMoreInfoHeader`).
@MainActor
final class StandaloneMoreInfoSheetModel: ObservableObject {
    @Published var title: String
    @Published var subtitle: String?
    @Published var isLoading: Bool
    @Published var navigation: StandaloneMoreInfoHeader.Navigation
    @Published var navigationLabel: String
    @Published var menuLabel: String
    @Published var actions: [StandaloneMoreInfoHeader.Action]
    @Published var menu: [StandaloneMoreInfoHeader.MenuItem]

    init(
        title: String = "",
        subtitle: String? = nil,
        isLoading: Bool = true,
        navigation: StandaloneMoreInfoHeader.Navigation = .close,
        navigationLabel: String = "",
        menuLabel: String = "",
        actions: [StandaloneMoreInfoHeader.Action] = [],
        menu: [StandaloneMoreInfoHeader.MenuItem] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isLoading = isLoading
        self.navigation = navigation
        self.navigationLabel = navigationLabel
        self.menuLabel = menuLabel
        self.actions = actions
        self.menu = menu
    }

    /// Takes over the header the frontend described.
    func apply(_ header: StandaloneMoreInfoHeader) {
        title = header.title
        subtitle = header.subtitle
        navigation = header.navigation
        navigationLabel = header.navigationLabel
        menuLabel = header.menuLabel
        actions = header.actions
        menu = header.menu
    }
}
