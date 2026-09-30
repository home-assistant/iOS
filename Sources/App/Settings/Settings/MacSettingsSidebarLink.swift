import Shared
import SwiftUI

/// A row of the settings list that opens a screen.
///
/// On iOS and under Mac Catalyst the row is a link that pushes its destination. In the native Mac app the
/// sidebar's selection decides what the detail column shows, so the row is only its label: a link there
/// would open the destination a second time, inside the sidebar column.
struct MacSettingsSidebarLink<Destination: View, Label: View>: View {
    private let destination: () -> Destination
    private let label: () -> Label

    init(destination: @autoclosure @escaping () -> Destination, @ViewBuilder label: @escaping () -> Label) {
        self.destination = destination
        self.label = label
    }

    var body: some View {
        #if os(macOS)
        label()
        #else
        NavigationLink(destination: destination()) {
            label()
        }
        #endif
    }
}

#Preview {
    List {
        MacSettingsSidebarLink(destination: Text(verbatim: "Destination")) {
            Text(verbatim: "Row")
        }
    }
}
