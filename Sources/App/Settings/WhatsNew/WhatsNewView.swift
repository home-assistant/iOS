import SFSafeSymbols
import Shared
import SwiftUI

struct WhatsNewFeatureItem: Identifiable {
    let id = UUID()
    let icon: SFSymbol
    let iconColor: Color
    let title: String
    let description: String

    /// The current release's feature highlights.
    /// Update these items each release to reflect the latest changes.
    /// Also update the corresponding strings in Sources/App/Resources/en.lproj/Localizable.strings.
    static var currentFeatures: [WhatsNewFeatureItem] {
        [
            WhatsNewFeatureItem(
                icon: .macwindow,
                iconColor: .haPrimary,
                title: L10n.Settings.WhatsNew.Feature1.title,
                description: L10n.Settings.WhatsNew.Feature1.description
            ),
            WhatsNewFeatureItem(
                icon: .bellBadge,
                iconColor: .blue,
                title: L10n.Settings.WhatsNew.Feature2.title,
                description: L10n.Settings.WhatsNew.Feature2.description
            ),
            WhatsNewFeatureItem(
                icon: .gearshape,
                iconColor: .gray,
                title: L10n.Settings.WhatsNew.Feature3.title,
                description: L10n.Settings.WhatsNew.Feature3.description
            ),
        ]
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    let features: [WhatsNewFeatureItem]
    let releaseNotesURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            titleSection
            featuresList
            Spacer(minLength: DesignSystem.Spaces.two)
            buttonsSection
        }
        .padding(DesignSystem.Spaces.three)
        .frame(width: 480, height: 520)
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(L10n.Settings.WhatsNew.title)
            .font(DesignSystem.Font.title.bold())
            .padding(.bottom, DesignSystem.Spaces.three)
    }

    // MARK: - Features List

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
            ForEach(features) { feature in
                featureRow(feature)
            }
        }
    }

    private func featureRow(_ feature: WhatsNewFeatureItem) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: feature.icon)
                .font(.system(size: 28))
                .foregroundColor(feature.iconColor)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(feature.title)
                    .font(DesignSystem.Font.headline)
                Text(feature.description)
                    .font(DesignSystem.Font.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        HStack {
            if let releaseNotesURL {
                Link(destination: releaseNotesURL) {
                    Text(L10n.Settings.WhatsNew.releaseNotes)
                }
                .buttonStyle(.outlinedButton)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(L10n.Settings.WhatsNew.continue)
            }
            .buttonStyle(.primaryButton)
        }
    }
}

#Preview {
    WhatsNewView(
        features: [
            WhatsNewFeatureItem(
                icon: .macwindow,
                iconColor: .haPrimary,
                title: "Refreshed Mac Experience",
                description: "The macOS experience has been refined with a cleaner interface and improved navigation."
            ),
            WhatsNewFeatureItem(
                icon: .bellBadge,
                iconColor: .blue,
                title: "Improved Notifications",
                description: "Richer notification controls with quick actions and inline media attachments."
            ),
            WhatsNewFeatureItem(
                icon: .gearshape,
                iconColor: .gray,
                title: "Redesigned Settings",
                description: "A cleaner, more organized settings experience to help you find what you need faster."
            ),
        ],
        releaseNotesURL: URL(string: "https://www.home-assistant.io/latest-ios-release-notes/")
    )
}
