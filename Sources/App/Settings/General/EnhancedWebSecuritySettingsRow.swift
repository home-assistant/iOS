import Shared
import SwiftUI

/// Lets someone opt back into WebKit's Enhanced Security heuristic on a plain-HTTP connection.
struct EnhancedWebSecuritySettingsRow: View {
    @StateObject private var viewModel: EnhancedWebSecuritySettingsViewModel

    // No default: the view model is main-actor isolated, and a default argument would be
    // evaluated outside that isolation.
    init(viewModel: EnhancedWebSecuritySettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        if viewModel.isRelevant {
            Section {
                Toggle(isOn: viewModel.enabled) {
                    Text(L10n.SettingsDetails.General.EnhancedWebSecurity.title)
                }
            } footer: {
                Text(L10n.SettingsDetails.General.EnhancedWebSecurity.footer)
            }
        }
    }
}

#Preview {
    List {
        EnhancedWebSecuritySettingsRow(viewModel: .init(isRelevant: true))
    }
}
