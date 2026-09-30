#if os(macOS)
import SwiftUI

/// Stands in for SwiftUI's `NavigationView` in the native Mac app.
///
/// The app uses `NavigationView` for a single stack of screens, which is what it is on iOS with the stack
/// style. On a Mac SwiftUI has no such style: a `NavigationView` always lays out in columns, putting a
/// screen meant to fill a sheet or a window into a sidebar next to an empty detail area. Declared here,
/// this type takes the name over for the app target and gives those screens the stack they were built for.
struct NavigationView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
        }
    }
}

#Preview {
    NavigationView {
        Text(verbatim: "Root")
            .navigationTitle(Text(verbatim: "Title"))
    }
}
#endif
