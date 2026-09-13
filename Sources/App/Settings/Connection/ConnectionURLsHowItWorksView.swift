import SFSafeSymbols
import Shared
import SwiftUI

/// Explains which URL the app reaches a server on — while it is open and while it is in the
/// background — and shows which of the requirements this device meets, plus the URL in use right now.
struct ConnectionURLsHowItWorksView: View {
    private struct Step: Identifiable {
        let symbol: SFSymbol
        let title: String
        let body: String

        var id: String { title }
    }

    @StateObject private var viewModel: ConnectionURLsHowItWorksViewModel

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: ConnectionURLsHowItWorksViewModel(server: server))
    }

    private let selectionSteps: [Step] = [
        Step(
            symbol: .houseFill,
            title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Home.title,
            body: L10n.Settings.ConnectionSection.UrlsHowItWorks.Home.body
        ),
        Step(
            symbol: .globe,
            title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Away.title,
            body: L10n.Settings.ConnectionSection.UrlsHowItWorks.Away.body
        ),
    ]

    private let exampleSteps: [Step] = [
        Step(
            symbol: .iphone,
            title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Foreground.title,
            body: L10n.Settings.ConnectionSection.UrlsHowItWorks.Foreground.body
        ),
        Step(
            symbol: .moonZzzFill,
            title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Background.title,
            body: L10n.Settings.ConnectionSection.UrlsHowItWorks.Background.body
        ),
    ]

    var body: some View {
        List {
            Section {
                Text(L10n.Settings.ConnectionSection.UrlsHowItWorks.intro)
                    .font(.body)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(selectionSteps) { step in
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: step.symbol)
                            .font(.title3)
                            .foregroundStyle(.haPrimary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spaces.half)
                }
            }

            Section {
                ForEach(exampleSteps) { step in
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: step.symbol)
                            .font(.title3)
                            .foregroundStyle(.haPrimary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spaces.half)
                }
            }

            Section {
                Text(viewModel.securityLevel.description)
            } header: {
                Text(L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.title)
            } footer: {
                Text(L10n.Settings.ConnectionSection.UrlsHowItWorks.SecurityLevel.footer)
            }

            Section {
                ForEach(viewModel.requirements) { requirement in
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: requirement.isMet ? .checkmarkCircleFill : .circle)
                            .font(.title3)
                            .foregroundStyle(requirement.isMet ? Color.green : Color.secondary)
                            .frame(width: 32)
                        Text(requirement.title)
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(requirement.title), \(requirement.statusDescription)")
                }
            } header: {
                Text(L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.header)
            } footer: {
                Text(L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.footer)
            }

            Section {
                Text(viewModel.activeURLType.description)

                if let activeURL = viewModel.activeURL {
                    Text(activeURL.absoluteString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                        .privacySensitive()
                        .screenCaptureProtected()
                } else {
                    Text(L10n.Settings.ConnectionSection.UrlsHowItWorks.Active.none)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.Settings.ConnectionSection.UrlsHowItWorks.Active.header)
            }
        }
        .navigationTitle(L10n.Settings.ConnectionSection.UrlsHowItWorks.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh()
        }
    }
}

#Preview {
    NavigationView {
        ConnectionURLsHowItWorksView(server: ServerFixture.withRemoteConnection)
    }
    .navigationViewStyle(.stack)
}
