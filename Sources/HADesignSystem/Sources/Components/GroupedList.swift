#if !os(watchOS)
import SwiftUI

/// A screen of settings: sections of rows, each with an optional header and an explanatory footer.
///
/// On iOS this is a `List`, which draws such a screen as inset grouped cards. A `List` on a Mac is a
/// table: its sections run together, and a footer is cut off at one line however long its text is. There
/// the screen is a grouped `Form` instead, which is how System Settings draws the same thing.
///
/// Use it for screens made of a known handful of rows. A list of data stays a `List`: a form builds every
/// row up front, and cannot reorder or swipe rows.
public struct GroupedList<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        #if os(macOS)
        Form {
            content
        }
        .formStyle(.grouped)
        #else
        List {
            content
        }
        #endif
    }
}

#Preview {
    GroupedList {
        Section {
            Toggle(isOn: .constant(true)) {
                Text(verbatim: "Setting")
            }
        } header: {
            Text(verbatim: "Header")
        } footer: {
            Text(verbatim: "A footer that explains, at some length, what turning the setting on will do.")
        }
    }
}
#endif
