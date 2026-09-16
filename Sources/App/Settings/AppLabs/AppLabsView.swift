import SFSafeSymbols
import Shared
import SwiftUI

struct AppLabsView: View {
    @ObservedObject private var appLabs = Current.appLabs
    private let features: [AppLabsFeature]

    /// Injectable so previews and tests can render the list for a device with no experimental
    /// features on offer, or with all of them, regardless of the device running them.
    init(features: [AppLabsFeature] = AppLabsFeature.availableFeatures) {
        self.features = features
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .flaskOutlineIcon,
                title: L10n.Settings.AppLabs.title,
                subtitle: L10n.Settings.AppLabs.Header.subtitle
            )

            Section {
                Label {
                    Text(L10n.Settings.AppLabs.TestflightOnly.body)
                        .font(.callout)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemSymbol: .infoCircle)
                        .foregroundColor(.haPrimary)
                }
            }

            if features.isEmpty {
                Section {
                    Text(L10n.Settings.AppLabs.emptyState)
                        .font(.callout)
                        .foregroundColor(.secondary)
                } header: {
                    Text(L10n.Settings.AppLabs.FeaturesSection.header)
                }
            }
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
        .listTopContentMargin()
    }
}

extension AppLabsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        AppLabsFeature.allCases.map { SettingsSearchEntry($0.title) }
    }
}

#Preview("Features") {
    NavigationView {
        AppLabsView(features: AppLabsFeature.allCases)
    }
}

#Preview("Empty") {
    NavigationView {
        AppLabsView(features: [])
    }
}
