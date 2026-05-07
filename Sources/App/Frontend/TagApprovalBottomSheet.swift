import Shared
import SwiftUI
import UIKit

struct TagApprovalBottomSheet: View {
    @State private var bottomSheetState: AppleLikeBottomSheetViewState?

    let tag: String
    let onAllowOnce: () -> Void
    let onAllowAlways: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        AppleLikeBottomSheet(
            title: L10n.Nfc.TagApproval.title,
            content: {
                VStack(spacing: DesignSystem.Spaces.three) {
                    Text(L10n.Nfc.TagApproval.description)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        UIPasteboard.general.string = tag
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(L10n.Nfc.TagApproval.TagId.title)
                                .font(DesignSystem.Font.caption2)
                                .padding(.leading)
                                .foregroundStyle(.secondary)
                            HStack(spacing: DesignSystem.Spaces.one) {
                                Text(tag)
                                    .font(.system(.footnote, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemSymbol: .docOnDoc)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.vertical, DesignSystem.Spaces.one)
                            .padding(.horizontal, DesignSystem.Spaces.two)
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Nfc.TagApproval.copyTag)

                    VStack(spacing: DesignSystem.Spaces.one) {
                        Button {
                            onAllowOnce()
                            bottomSheetState = .dismiss
                        } label: {
                            Text(L10n.Nfc.TagApproval.allowOnce)
                        }
                        .buttonStyle(.primaryButton)

                        Button {
                            onAllowAlways()
                            bottomSheetState = .dismiss
                        } label: {
                            Text(L10n.Nfc.TagApproval.allowAlways)
                        }
                        .buttonStyle(.secondaryButton)
                    }
                }
            },
            contentInsets: .init(
                top: .zero,
                leading: DesignSystem.Spaces.two,
                bottom: DesignSystem.Spaces.three,
                trailing: DesignSystem.Spaces.two
            ),
            bottomSheetMinHeight: 320,
            state: $bottomSheetState,
            customDismiss: onDismiss
        )
    }
}

#Preview {
    TagApprovalBottomSheet(
        tag: "1234-5678-9012",
        onAllowOnce: {},
        onAllowAlways: {},
        onDismiss: {}
    )
}
