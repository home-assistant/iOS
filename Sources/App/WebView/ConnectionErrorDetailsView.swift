import SFSafeSymbols
import Shared
import SwiftUI

struct ConnectionErrorDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showExportLogsShareSheet: Bool = false

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
                VStack(alignment: .leading) {
                    headerView
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading, spacing: Spaces.two) {
                            Text(verbatim: L10n.Connection.Error.FailedConnect.title)
                                .font(.title.bold())
                            Text(verbatim: L10n.Connection.Error.FailedConnect.subtitle)
                            if let urlError = error as? URLError,
                               let url = urlError.failingURL?.absoluteString,
                               let attributedString = try? AttributedString(markdown: "[\(url)](\(url))") {
                                VStack {
                                    Text(verbatim: L10n.Connection.Error.FailedConnect.url)
                                        .font(.footnote)
                                    Text(attributedString)
                                        .font(.body.bold())
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: 600)
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if let server, server.info.connection.canUseCloud,
                               let cloudText = try? AttributedString(
                                   markdown: L10n.Connection.Error.FailedConnect.Cloud
                                       .title
                               ) {
                                if server.info.connection.useCloud {
                                    Text(cloudText)
                                        .font(.body.italic())
                                } else {
                                    // Alert user when it has deactivated cloud usage in the App
                                    Text(verbatim: L10n.Connection.Error.FailedConnect.CloudInactive.title)
                                }
                            }
                        }
                        if showSettingsEntry {
                            openSettingsButton
                        }
                        CollapsibleView(startExpanded: expandMoreDetails) {
                            Text(L10n.ConnectionError.MoreDetailsSection.title)
                                .font(.body.bold())
                        } expandedContent: {
                            advancedContent
                        }
                        .frame(maxWidth: 600)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top)

                        Rectangle()
                            .foregroundStyle(Color(uiColor: .label).opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                            .padding(Spaces.three)
                        copyToClipboardButton
                        exportLogsButton
                        documentationLink
                        discordLink
                        githubLink
                    }
                    .padding()
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showSettingsEntry {
                        Button(action: {
                            openSettings()
                        }, label: {
                            Image(uiImage: MaterialDesignIcons.cogIcon.image(
                                ofSize: .init(width: 28, height: 28),
                                color: .white
                            ))
                        })
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton(tint: .white) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showExportLogsShareSheet, content: {
                ShareActivityView(activityItems: [Current.Log.archiveURL()])
            })
        }
        .navigationViewStyle(.stack)
    }

    private func openSettings() {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise).done { controller in
            controller.showSettingsViewController()
        }
    }

    private var headerView: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: Asset.SharedAssets.logo.image.withRenderingMode(.alwaysTemplate))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 100)
                Image(systemSymbol: .wifiExclamationmark)
                    .foregroundStyle(.red)
                    .padding(Spaces.one)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 50))
                    .shadow(radius: 10)
                    .offset(y: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 140)
        .padding()
        .background(Color.asset(Asset.Colors.haPrimary))
    }

    @ViewBuilder
    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: Spaces.two) {
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
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline.bold())
            Text(body)
                .textSelection(.enabled)
        }
    }

    private var copyToClipboardButton: some View {
        ActionLinkButton(
            icon: Image(systemSymbol: .docOnDoc),
            title: L10n.Connection.Error.Details.Button.clipboard,
            tint: .init(uiColor: Asset.Colors.haPrimary.color)
        ) {
            UIPasteboard.general
                .string =
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
    }

    private var exportLogsButton: some View {
        ActionLinkButton(
            icon: Image(systemSymbol: .squareAndArrowUp),
            title: Current.Log.exportTitle,
            tint: .init(uiColor: Asset.Colors.haPrimary.color)
        ) {
            if Current.isCatalyst, let logsURL = Current.Log.archiveURL() {
                UIApplication.shared.open(logsURL)
            } else {
                showExportLogsShareSheet = true
                feedbackGenerator.notificationOccurred(.success)
            }
        }
    }

    private var openSettingsButton: some View {
        ActionLinkButton(
            icon: Image(uiImage: MaterialDesignIcons.cogIcon.image(
                ofSize: .init(width: 28, height: 28),
                color: .label
            )),
            title: L10n.ConnectionError.OpenSettings.title,
            tint: .init(uiColor: Asset.Colors.haPrimary.color)
        ) {
            openSettings()
        }
        .padding(.top)
    }

    private var documentationLink: some View {
        ExternalLinkButton(
            icon: Image(systemSymbol: .docTextFill),
            title: L10n.Connection.Error.Details.Button.doc,
            url: ExternalLink.companionAppDocs,
            tint: .init(uiColor: Asset.Colors.haPrimary.color)
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
