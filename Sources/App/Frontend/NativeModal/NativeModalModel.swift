import Combine
import Foundation

/// What a native modal's chrome shows: the frontend header's title, breadcrumb,
/// buttons and menu, and whether the page is still booting behind the native loader.
///
/// The title and subtitle first come with `modal/open`, so the bar is right from the first
/// frame; everything else, and every later change, comes with `modal/header` from the modal's
/// own frontend (see `NativeModalHeader`).
@MainActor
final class NativeModalModel: ObservableObject {
    @Published var title: String
    @Published var subtitle: String?
    @Published var isLoading: Bool
    @Published var navigation: NativeModalHeader.Navigation
    @Published var navigationLabel: String
    @Published var menuLabel: String
    @Published var actions: [NativeModalHeader.Action]
    @Published var menu: [NativeModalHeader.MenuItem]

    init(
        title: String = "",
        subtitle: String? = nil,
        isLoading: Bool = true,
        navigation: NativeModalHeader.Navigation = .close,
        navigationLabel: String = "",
        menuLabel: String = "",
        actions: [NativeModalHeader.Action] = [],
        menu: [NativeModalHeader.MenuItem] = []
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
    func apply(_ header: NativeModalHeader) {
        title = header.title
        subtitle = header.subtitle
        navigation = header.navigation
        navigationLabel = header.navigationLabel
        menuLabel = header.menuLabel
        actions = header.actions
        menu = header.menu
    }
}
