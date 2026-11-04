import Shared
import SwiftUI
import UIKit

struct TagApprovalSheet: View {
    @State private var isSheetPresented = false

    let tag: String
    let onAllowOnce: () -> Void
    let onAllowAlways: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .onAppear {
                isSheetPresented = true
            }
            .sheet(isPresented: $isSheetPresented, onDismiss: onDismiss) {
                NavigationStack {
                    content
                        .padding(.horizontal, DesignSystem.Spaces.two)
                        .padding(.bottom, DesignSystem.Spaces.two)
                        .navigationTitle(L10n.Nfc.TagApproval.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                CloseButton(size: .medium) {
                                    isSheetPresented = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
    }

    private var content: some View {
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

            Spacer()

            VStack(spacing: DesignSystem.Spaces.one) {
                Button {
                    onAllowOnce()
                    isSheetPresented = false
                } label: {
                    Text(L10n.Nfc.TagApproval.allowOnce)
                }
                .buttonStyle(.primaryButton)

                Button {
                    onAllowAlways()
                    isSheetPresented = false
                } label: {
                    Text(L10n.Nfc.TagApproval.allowAlways)
                }
                .buttonStyle(.secondaryButton)
            }
        }
        .padding(.top)
    }
}

#Preview {
    TagApprovalSheet(
        tag: "1234-5678-9012",
        onAllowOnce: {},
        onAllowAlways: {},
        onDismiss: {}
    )
}
