import Shared
import SwiftUI

/// Explains why the watch doesn't use the internal URL by default (it can't verify the Wi-Fi
/// network it's on) and what happens while no trusted URL exists — data doesn't sync and
/// complications don't update. When the server has an internal URL, the user can opt into it
/// from here (same per-server override as the settings picker).
struct WatchInternalURLInfoView: View {
    let prompt: WatchInternalURLPromptContext
    let onUse: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                Text(verbatim: L10n.Watch.InternalUrlPrompt.Info.title)
                    .font(.headline)
                Text(verbatim: L10n.Watch.InternalUrlPrompt.Info.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let internalURL = prompt.internalURL {
                    Button(role: .destructive) {
                        onUse()
                    } label: {
                        Text(verbatim: L10n.Watch.InternalUrlPrompt.Info.use(internalURL.absoluteString))
                            .frame(maxWidth: .infinity)
                    }
                }
                Button {
                    onNotNow()
                } label: {
                    Text(verbatim: L10n.Watch.InternalUrlPrompt.Info.notNow)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    WatchInternalURLInfoView(
        prompt: .init(
            serverId: "server1",
            serverName: "Home",
            internalURL: URL(string: "http://192.168.0.10:8123")
        ),
        onUse: {},
        onNotNow: {}
    )
}
