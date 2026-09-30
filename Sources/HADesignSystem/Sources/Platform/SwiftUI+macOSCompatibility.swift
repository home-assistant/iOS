#if os(macOS)
import SwiftUI

// The screens are written once for iOS and macOS. SwiftUI marks its navigation bar, keyboard and
// full-screen presentation API unavailable on macOS rather than ignoring it, which would otherwise put
// an `#if` around a modifier on nearly every screen. The declarations below take their place on macOS:
// each one either maps to what the Mac offers instead or does nothing where the concept has no Mac
// equivalent. The compiler prefers them because the SwiftUI originals are unavailable here.

// MARK: - Navigation bar

/// Stands in for `NavigationBarItem.TitleDisplayMode`. A Mac window has a single title style.
public enum NavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
}

public extension View {
    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarTitleDisplayMode) -> some View {
        self
    }

    func navigationBarHidden(_ hidden: Bool) -> some View {
        self
    }

    func statusBarHidden(_ hidden: Bool = true) -> some View {
        self
    }
}

public extension NavigationViewStyle where Self == DefaultNavigationViewStyle {
    /// A Mac window has room for the columns a stack style exists to avoid.
    static var stack: DefaultNavigationViewStyle { .automatic }
}

public extension ToolbarItemPlacement {
    static var topBarLeading: ToolbarItemPlacement { .navigation }
    static var topBarTrailing: ToolbarItemPlacement { .primaryAction }
    static var navigationBarLeading: ToolbarItemPlacement { .navigation }
    static var navigationBarTrailing: ToolbarItemPlacement { .primaryAction }
    static var bottomBar: ToolbarItemPlacement { .automatic }
}

// MARK: - Presentation

public extension View {
    /// A Mac app presents in a sheet attached to its window; there is no full-screen cover.
    func fullScreenCover(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .environment(\.isPresentedInMacSheet, true)
        }
    }

    /// A Mac app presents in a sheet attached to its window; there is no full-screen cover.
    func fullScreenCover<Item: Identifiable>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            content(item)
                .environment(\.isPresentedInMacSheet, true)
        }
    }
}

// MARK: - Lists

public extension ListStyle where Self == InsetListStyle {
    static var insetGrouped: InsetListStyle { .inset }
    static var grouped: InsetListStyle { .inset }
}

/// Stands in for `ListSectionSpacing`. A Mac list spaces its sections itself.
public enum ListSectionSpacing {
    case `default`
    case compact

    public static func custom(_ spacing: CGFloat) -> ListSectionSpacing { .default }
}

public extension View {
    func listSectionSpacing(_ spacing: ListSectionSpacing) -> some View {
        self
    }

    func listSectionSpacing(_ spacing: CGFloat) -> some View {
        self
    }

    func listRowSpacing(_ spacing: CGFloat?) -> some View {
        self
    }
}

// MARK: - Text input

/// Stands in for `UIKeyboardType`. A Mac has one keyboard, so the choice is dropped.
public enum KeyboardType {
    case `default`
    case asciiCapable
    case numbersAndPunctuation
    case URL
    case numberPad
    case phonePad
    case namePhonePad
    case emailAddress
    case decimalPad
    case twitter
    case webSearch
    case asciiCapableNumberPad
}

/// Stands in for `TextInputAutocapitalization`. A Mac text field never capitalizes on its own.
public enum TextInputAutocapitalization {
    case never
    case words
    case sentences
    case characters
}

/// Stands in for `UITextAutocapitalizationType`, which the older `autocapitalization(_:)` modifier takes.
public enum TextAutocapitalizationType {
    case none
    case words
    case sentences
    case allCharacters
}

public extension View {
    func keyboardType(_ type: KeyboardType) -> some View {
        self
    }

    func autocapitalization(_ style: TextAutocapitalizationType) -> some View {
        self
    }

    func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View {
        self
    }
}
#endif
