import Shared
import SwiftUI

/// Row that opens `ConnectionURLsHowItWorksView`. Lives on both the server's connection settings and
/// the internal URL screen, so the explanation is one tap away from wherever a URL is being set up.
struct ConnectionURLsHowItWorksLink: View {
    let server: Server

    var body: some View {
        NavigationLink {
            ConnectionURLsHowItWorksView(server: server)
        } label: {
            Text(L10n.Settings.ConnectionSection.UrlsHowItWorks.title)
        }
    }
}

#Preview {
    NavigationView {
        List {
            ConnectionURLsHowItWorksLink(server: ServerFixture.withRemoteConnection)
        }
    }
    .navigationViewStyle(.stack)
}
