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
            Text(L10n.WhatsNew.title)
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

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spaces.three) {
            WhatsNewIconView(icon: item.icon, color: iconColor)
                .frame(width: 48, height: 48)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
