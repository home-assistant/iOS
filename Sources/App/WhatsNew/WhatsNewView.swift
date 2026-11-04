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
            ForEach(release.items) { item in
                WhatsNewItemRow(item: item)
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
            WhatsNewIconView(icon: item.icon, color: .haPrimary)
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

#Preview {
    WhatsNewView(release: WhatsNewCatalog.mock, onViewed: {})
}
