import SFSafeSymbols
import Shared
import SwiftUI

struct ConnectionErrorDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showExportLogsShareSheet: Bool = false
    @StateObject private var connectivityState = ConnectivityCheckState()

    private let feedbackGenerator = UINotificationFeedbackGenerator()
    let server: Server?
    let error: Error
    let showSettingsEntry: Bool
    let expandMoreDetails: Bool

    init(server: Server?, error: Error, showSettingsEntry: Bool = true, expandMoreDetails: Bool = false) {
        self.server = server
        self.error = error
        self.showSettingsEntry = showSettingsEntry
        self.expandMoreDetails = expandMoreDetails
    }

    var body: some View {
        NavigationView {
            ScrollView {
                content
            }
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom) {
                bottomActions
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showExportLogsShareSheet, content: {
                if let archiveURL = Current.Log.archiveURL() {
                    ShareActivityView(activityItems: [archiveURL])
                }
            })
        }
        .navigationViewStyle(.stack)
    }

    private var content: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            summaryHeader
            if showsConnectionSection {
                connectionSection
            }
            detailsSection
            supportSection
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.top, Current.isCatalyst ? DesignSystem.Spaces.two : DesignSystem.Spaces.five)
        .padding(.bottom, DesignSystem.Spaces.six)
    }

    private var summaryHeader: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            headerIcon
            VStack(spacing: DesignSystem.Spaces.one) {
                Text(verbatim: L10n.Connection.Error.FailedConnect.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text(verbatim: L10n.Connection.Error.FailedConnect.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spaces.two)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var headerIcon: some View {
        ZStack(alignment: .topTrailing) {
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            Image(systemSymbol: .wifiExclamationmark)
                .font(.title3)
                .foregroundStyle(.red)
                .padding(DesignSystem.Spaces.half)
                .background(Color(uiColor: .systemBackground))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                .offset(x: DesignSystem.Spaces.half, y: DesignSystem.Spaces.half)
        }
        .accessibilityHidden(true)
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            failingURLView
            cloudStatusView
        }
        .sectionStyle()
    }

    private var showsConnectionSection: Bool {
        (error as? URLError)?.failingURL != nil || server?.info.connection.canUseCloud == true
    }

    @ViewBuilder
    private var failingURLView: some View {
        if let urlError = error as? URLError,
           let url = urlError.failingURL?.absoluteString,
           let attributedString = try? AttributedString(markdown: "[\(url)](\(url))") {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(verbatim: L10n.Connection.Error.FailedConnect.url)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(attributedString)
                    .font(.callout.bold())
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var cloudStatusView: some View {
        if let server, server.info.connection.canUseCloud,
           let cloudText = try? AttributedString(
               markdown: L10n.Connection.Error.FailedConnect.Cloud.title
           ) {
            if server.info.connection.useCloud {
                Text(cloudText)
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
            } else {
                // Alert user when it has deactivated cloud usage in the App
                Text(verbatim: L10n.Connection.Error.FailedConnect.CloudInactive.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailsSection: some View {
        CollapsibleView(startExpanded: expandMoreDetails) {
            Text(L10n.ConnectionError.MoreDetailsSection.title)
                .font(.callout.bold())
        } expandedContent: {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
                advancedContent
                troubleShootingView
            }
        }
        .sectionStyle()
    }

    @ViewBuilder
    private var troubleShootingView: some View {
        if let url = extractURL() {
            ConnectivityCheckView(
                state: connectivityState,
                url: url,
                onRunChecks: {
                    runConnectivityChecks(url: url)
                }
            )
        }
    }

    @ViewBuilder
    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            makeRow(title: L10n.Connection.Error.Details.Label.description, body: error.localizedDescription)
            makeRow(title: L10n.Connection.Error.Details.Label.domain, body: (error as NSError).domain)
            makeRow(title: L10n.Connection.Error.Details.Label.code, body: "\((error as NSError).code)")
            if let urlError = error as? URLError {
                makeRow(title: L10n.urlLabel, body: urlError.failingURL?.absoluteString ?? "")
            }
        }
        .padding(.vertical)
    }

    private func makeRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(body)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            exportLogsButton
            documentationLink
            discordLink
            githubLink
        }
    }

    private var bottomActions: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            if showSettingsEntry {
                Button(action: {
                    openSettings()
                }) {
                    Text(L10n.ConnectionError.OpenSettings.title)
                }
                .buttonStyle(.primaryButton)
            }
            Button(action: {
                copyErrorDetailsToClipboard()
            }) {
                Text(L10n.Connection.Error.Details.Button.clipboard)
            }
            .buttonStyle(.secondaryButton)
        }
        .padding(.bottom, Current.isCatalyst ? DesignSystem.Spaces.two : .zero)
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding([.horizontal, .top], DesignSystem.Spaces.two)
        .background(Color(uiColor: .systemBackground).opacity(0.95))
    }

    private func openSettings() {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise).done { controller in
            controller.showSettingsViewController()
        }
    }

    private func extractURL() -> URL? {
        // Try to extract URL from error
        if let urlError = error as? URLError, let url = urlError.failingURL {
            return url
        }

        // Try to extract from server
        if let server {
            if let externalURL = server.info.connection.urlForTroubleshooting(type: .external) {
                return externalURL
            } else if let internalURL = server.info.connection.urlForTroubleshooting(type: .internal) {
                return internalURL
            }
        }

        return nil
    }

    private func runConnectivityChecks(url: URL) {
        Task {
            let checker = ConnectivityChecker(state: connectivityState)
            await checker.runChecks(for: url)
        }
    }

    private func copyErrorDetailsToClipboard() {
        UIPasteboard.general.string =
            """
            \(L10n.Connection.Error.Details.Label.description): \n
            \(error.localizedDescription) \n
            \(L10n.Connection.Error.Details.Label.domain): \n
            \((error as NSError).domain) \n
            \(L10n.Connection.Error.Details.Label.code): \n
            \((error as NSError).code) \n
            \(L10n.urlLabel): \n
            \((error as? URLError)?.failingURL?.absoluteString ?? "")
            """
        feedbackGenerator.notificationOccurred(.success)
    }

    private var exportLogsButton: some View {
        ActionLinkButton(
            icon: Image(systemSymbol: .squareAndArrowUp),
            title: Current.Log.exportTitle,
            tint: .haPrimary
        ) {
            if Current.isCatalyst, let logsURL = Current.Log.archiveURL() {
                URLOpener.shared.open(logsURL, options: [:], completionHandler: nil)
            } else {
                showExportLogsShareSheet = true
                feedbackGenerator.notificationOccurred(.success)
            }
        }
    }

    private var documentationLink: some View {
        ExternalLinkButton(
            icon: Image(systemSymbol: .docTextFill),
            title: L10n.Connection.Error.Details.Button.doc,
            url: ExternalLink.companionAppDocs,
            tint: .haPrimary
        )
    }

    private var discordLink: some View {
        ExternalLinkButton(
            icon: Image("discord.fill"),
            title: L10n.Connection.Error.Details.Button.discord,
            url: ExternalLink.discord,
            tint: .purple
        )
    }

    @ViewBuilder
    private var githubLink: some View {
        if let searchURL = ExternalLink.githubSearchIssue(domain: (error as NSError).domain) {
            ExternalLinkButton(
                icon: Image("github.fill"),
                title: L10n.Connection.Error.Details.Button.searchGithub,
                url: searchURL,
                tint: .init(uiColor: .init(dynamicProvider: { trait in
                    trait.userInterfaceStyle == .dark ? .white : .black
                }))
            )
        }
    }
}

private extension View {
    func sectionStyle() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
    }
}

#Preview {
    VStack {}
        .background(Color.gray)
        .sheet(isPresented: .constant(true)) {
            ConnectionErrorDetailsView(server: ServerFixture.standard, error: SomeError.some)
        }
}

enum SomeError: Error {
    case some
}
