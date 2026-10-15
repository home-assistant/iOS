import Shared
import SwiftUI

/// A settings screen presented as a sheet from the server details: its own navigation stack with a
/// close button, zooming out of the control that opened it when a transition source is given.
struct ServerSettingsSheet<Content: View>: View {
    let zoomSourceID: ServerDetailsRowView.EditOption?
    let transitionNamespace: Namespace.ID?
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        NavigationView {
            content
                .navigationViewStyle(.stack)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton(alternativeAction: onClose)
                    }
                }
        }
        .modify { view in
            if #available(iOS 18.0, *), let zoomSourceID, let transitionNamespace {
                view.navigationTransition(.zoom(sourceID: zoomSourceID, in: transitionNamespace))
            } else {
                view
            }
        }
    }
}

#Preview {
    ServerSettingsSheet(zoomSourceID: nil, transitionNamespace: nil, onClose: {}) {
        ConnectionURLView(server: ServerFixture.standard, urlType: .internal)
    }
}
