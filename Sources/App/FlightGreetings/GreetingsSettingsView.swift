import Shared
import SwiftUI

struct GreetingsSettingsView: View {
    @State private var flightGreetingsEnabled = Current.settingsStore.flightGreetingsEnabled

    var body: some View {
        List {
            Section(footer: Text(L10n.Settings.Greetings.Flight.footer)) {
                Toggle(L10n.Settings.Greetings.Flight.title, isOn: $flightGreetingsEnabled)
                    .onChange(of: flightGreetingsEnabled) { value in
                        Current.settingsStore.flightGreetingsEnabled = value
                    }
            }
        }
        .navigationTitle(L10n.Settings.Greetings.title)
        .modify { view in
            if #available(iOS 17.0, *) {
                view.contentMargins(.top, DesignSystem.Spaces.half)
            } else {
                view
            }
        }
    }

    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.Greetings.Flight.title),
        ]
    }
}

#Preview {
    NavigationView {
        GreetingsSettingsView()
    }
}
