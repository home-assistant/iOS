import Shared
import SwiftUI

/// The native article pushed when a What's New item with an `.article` destination is tapped: a header
/// icon, a title, a Markdown body, and an optional action button that opens a link in a Safari sheet.
struct WhatsNewArticleView: View {
    let article: ArticleMessage

    @State private var presentedURL: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.four) {
                WhatsNewIconView(icon: article.icon, color: .haPrimary)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)

                Text(article.title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                articleBody
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spaces.four)
            .padding(.top, DesignSystem.Spaces.two)
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let action = article.action {
                Button {
                    presentedURL = IdentifiableURL(url: action.url)
                } label: {
                    Text(action.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryButton)
                .padding([.horizontal, .bottom])
            }
        }
        .sheet(item: $presentedURL) { item in
            SafariWebView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private var articleBody: Text {
        if let attributed = try? AttributedString(
            markdown: article.body,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(article.body)
    }
}

#Preview {
    NavigationView {
        WhatsNewArticleView(article: ArticleMessage(
            icon: .sfSymbol(.boltFill),
            title: "Energy widget",
            body: "A longer **Markdown** explanation of the change.\n\nWith a second paragraph.",
            action: .init(title: "Learn more", url: URL(string: "https://www.home-assistant.io/")!)
        ))
    }
}
