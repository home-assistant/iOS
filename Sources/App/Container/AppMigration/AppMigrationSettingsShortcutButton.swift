import SFSafeSymbols
import Shared
import SwiftUI

/// The gear in the top-leading corner of the failure screen.
///
/// The migration is presented full screen and cannot be dismissed by swiping, so a user who hits a
/// failure would otherwise have no way to reach Settings — which is exactly where they would go to
/// check the server, sign in again, or look at the logs to work out why it failed.
struct AppMigrationSettingsShortcutButton: View {
    @State private var isShowingSettings = false

    var body: some View {
        Button {
            isShowingSettings = true
        } label: {
            Image(systemSymbol: .gearshape)
                .font(.title3)
                .foregroundStyle(Color.haPrimary)
                .padding(DesignSystem.Spaces.one)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.Settings.NavigationBar.title)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .injectingViewControllerProvider()
        }
    }
}

#Preview {
    AppMigrationSettingsShortcutButton()
}
