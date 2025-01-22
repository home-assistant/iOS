import SFSafeSymbols
import Shared
import SwiftUI

struct ConnectionErrorDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let error: Error
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    SheetCloseButton {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Text(L10n.Connection.Error.Details.title)
                    .font(.title.bold())
                VStack(alignment: .leading, spacing: Spaces.two) {
                    makeRow(title: L10n.Connection.Error.Details.Label.description, body: error.localizedDescription)
                    makeRow(title: L10n.Connection.Error.Details.Label.domain, body: (error as NSError).domain)
                    makeRow(title: L10n.Connection.Error.Details.Label.code, body: "\((error as NSError).code)")
                    if let urlError = error as? URLError {
                        makeRow(title: L10n.urlLabel, body: urlError.failingURL?.absoluteString ?? "")
                    }
                }
                .padding(.vertical)
                copyToClipboardButton
                documentationLink
                discordLink
                githubLink
            }
            .padding()
        }
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
                "Description: \n \(error.localizedDescription) \n Domain: \n \((error as NSError).domain) \n Code: \n \((error as NSError).code) \n URL: \n \((error as? URLError)?.failingURL?.absoluteString ?? "")"
        }
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
    ConnectionErrorDetailsView(error: SomeError.some)
}

enum SomeError: Error {
    case some
}
