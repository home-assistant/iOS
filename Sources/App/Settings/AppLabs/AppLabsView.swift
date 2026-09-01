import Shared
import SwiftUI

struct AppLabsView: View {
    @ObservedObject private var appLabs = Current.appLabs

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .flaskOutlineIcon,
                title: L10n.Settings.AppLabs.title,
                subtitle: L10n.Settings.AppLabs.Header.subtitle
            )

            let features = AppLabsFeature.availableFeatures
            if features.isEmpty {
                Section(header: Text(L10n.Settings.AppLabs.FeaturesSection.header)) {
                    Text(L10n.Settings.AppLabs.emptyState)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(features) { feature in
                    Section {
                        Toggle(isOn: .init(get: {
                            feature.isEnabled(in: appLabs.enabledFeatureIds)
                        }, set: { newValue in
                            feature.isEnabled = newValue
                        })) {
                            Text(feature.title)
                        }
                    } header: {
                        if feature == features.first {
                            Text(L10n.Settings.AppLabs.FeaturesSection.header)
                        }
                    } footer: {
                        Text(feature.footer)
                    }
                }
            }
        }
        .listTopContentMargin()
    }
}

extension AppLabsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        AppLabsFeature.allCases.map { SettingsSearchEntry($0.title) }
    }
}

#Preview {
    NavigationView {
        AppLabsView()
    }
}
