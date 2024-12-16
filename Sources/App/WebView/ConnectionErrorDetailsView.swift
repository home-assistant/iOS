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
                }
                .padding(.vertical)
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

    private var githubLink: some View {
        ExternalLinkButton(
            icon: Image("github.fill"),
            title: L10n.Connection.Error.Details.Button.github,
            url: ExternalLink.githubReportIssue,
            tint: .black
        )
    }
}

#Preview {
    ConnectionErrorDetailsView(error: SomeError.some)
}

enum SomeError: Error {
    case some
}
