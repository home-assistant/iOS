import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

struct WhatsNewView: View {
    let release: WhatsNewRelease
    let onViewed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didRecordView = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.five) {
                    header
                    items
                }
                .padding(.horizontal, DesignSystem.Spaces.four)
                .padding(.top, DesignSystem.Spaces.two)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                continueButton
            }
            .onAppear {
                recordViewIfNeeded()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text(release.title ?? L10n.WhatsNew.title)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.four) {
            ForEach(Array(release.items.enumerated()), id: \.element.id) { offset, item in
                WhatsNewItemRow(item: item, iconColor: WhatsNewColors.iconColor(for: offset))
            }
        }
    }

    private var continueButton: some View {
        Button {
            dismiss()
        } label: {
            Text(L10n.continueLabel)
        }
        .buttonStyle(.primaryButton)
        .padding([.horizontal, .bottom])
    }

    private func recordViewIfNeeded() {
        guard !didRecordView else { return }
        didRecordView = true
        onViewed()
    }
}

private struct WhatsNewItemRow: View {
    let item: WhatsNewItem
    let iconColor: UIColor

    @State private var presentedURL: IdentifiableURL?

    var body: some View {
        if let destination = item.destination {
            switch destination {
            case let .link(url):
                // Presented as a sheet: SFSafariViewController has its own close button, which would
                // collide with a navigation back button if pushed.
                Button {
                    presentedURL = IdentifiableURL(url: url)
                } label: {
                    content(showsLinkAffordance: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.WhatsNew.Item.opensLinkHint)
                .sheet(item: $presentedURL) { item in
                    SafariWebView(url: item.url)
                        .ignoresSafeArea()
                }
            case let .article(article):
                NavigationLink {
                    WhatsNewArticleView(article: article)
                } label: {
                    content(showsLinkAffordance: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.WhatsNew.Item.opensArticleHint)
            }
        } else {
            content(showsLinkAffordance: false)
        }
    }

    private func content(showsLinkAffordance: Bool) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Spaces.two) {
            WhatsNewIconView(icon: item.icon, color: iconColor)
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsLinkAffordance {
                Image(systemSymbol: .chevronForward)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct WhatsNewArticleView: View {
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

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct WhatsNewIconView: View {
    let icon: WhatsNewIcon
    let color: UIColor

    var body: some View {
        switch icon {
        case let .sfSymbol(symbol):
            Image(systemSymbol: symbol)
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(Color(uiColor: color))
        case let .materialDesign(icon):
            Image(uiImage: icon.image(ofSize: CGSize(width: 38, height: 38), color: color))
                .renderingMode(.template)
                .foregroundStyle(Color(uiColor: color))
        }
    }
}

private enum WhatsNewColors {
    private static let colors: [UIColor] = [
        .haPrimary,
        .systemRed,
        .systemGreen,
        .systemBlue,
        .systemOrange,
    ]

    static func iconColor(for index: Int) -> UIColor {
        colors[index % colors.count]
    }
}
