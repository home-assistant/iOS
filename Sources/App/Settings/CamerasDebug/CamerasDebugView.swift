import Shared
import SwiftUI

/// Debug screen listing every configured server. Selecting a server drills into
/// its camera entities so their live streams can be previewed for troubleshooting.
struct CamerasDebugView: View {
    @StateObject private var observer = ServersObserver()

    var body: some View {
        List {
            Section {
                ForEach(observer.servers, id: \.identifier) { server in
                    NavigationLink(destination: CamerasDebugServerView(server: server)) {
                        HomeAssistantAccountRowView(server: server)
                    }
                }
            } footer: {
                Text(verbatim: "Select a server to browse its camera entities and preview their live streams.")
            }
        }
        .navigationTitle("Cameras Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        CamerasDebugView()
    }
}
