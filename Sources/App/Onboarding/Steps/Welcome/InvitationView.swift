import Foundation
import Shared
import SwiftUI

struct InvitationView: View {
    private enum Constants {
        static let logoWidth: CGFloat = 110
        static let logoHeight: CGFloat = 110
    }

    let invitationURL: URL
    let isAccepting: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.one) {
                Spacer()
                logoBlock
                textBlock
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
            .padding(.top, DesignSystem.Spaces.six)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, content: {
            continueButtonBlock
        })
    }

    private var logoBlock: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            Image(.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .accessibilityLabel(L10n.Onboarding.Welcome.Logo.accessibilityLabel)
                .frame(
                    width: Constants.logoWidth,
                    height: Constants.logoHeight,
                    alignment: .center
                )
            Text(L10n.Onboarding.Invitation.screenTitle)
                .font(DesignSystem.Font.largeTitle.bold())
                .padding(.horizontal, DesignSystem.Spaces.two)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var textBlock: some View {
        VStack(alignment: .center, spacing: DesignSystem.Spaces.three) {
            Text(L10n.Onboarding.Invitation.description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ZStack(alignment: .topTrailing) {
                VStack {
                    VStack(alignment: .leading) {
                        Text(L10n.Onboarding.Invitation.addressTitle)
                            .foregroundStyle(.secondary)
                            .font(DesignSystem.Font.caption)
                        Link(destination: invitationURL) {
                            Text(invitationURL.absoluteString)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .privacySensitive()
                                .screenCaptureProtected()
                                .font(DesignSystem.Font.subheadline)
                                .padding(.horizontal, DesignSystem.Spaces.two)
                                .padding(.vertical, DesignSystem.Spaces.half)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(.capsule)
                        }
                        .padding(.trailing, DesignSystem.Spaces.four)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Label(
                        L10n.Onboarding.Invitation.securityWarning,
                        systemSymbol: .lock
                    )
                    .font(DesignSystem.Font.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignSystem.Spaces.two)
                }
                .padding(DesignSystem.Spaces.two)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two)
                        .stroke(
                            .secondary,
                            style: StrokeStyle(
                                lineWidth: DesignSystem.Border.Width.default,
                                dash: [
                                    DesignSystem.Spaces.half,
                                    DesignSystem.Spaces.micro,
                                ]
                            )
                        )
                }
                Image(systemSymbol: .envelopeBadgeFill)
                    .foregroundStyle(.accent)
                    .padding(DesignSystem.Spaces.two)
            }
        }
        .padding(DesignSystem.Spaces.two)
    }

    private var continueButtonBlock: some View {
        VStack {
            Button(action: onAccept) {
                ZStack {
                    HAProgressView(colorType: .light)
                        .opacity(isAccepting ? 1 : 0)
                    Text(L10n.Onboarding.Invitation.acceptButton)
                        .opacity(isAccepting ? 0 : 1)
                }
            }
            .buttonStyle(.primaryButton)
            .disabled(isAccepting)
            Button(L10n.Onboarding.Invitation.rejectButton, action: onReject)
                .tint(Color.haPrimary)
                .buttonStyle(.secondaryButton)
                .disabled(isAccepting)
        }
        .padding([.horizontal, .top], DesignSystem.Spaces.two)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    NavigationView {
        InvitationView(
            invitationURL: URL(string: "http://192.168.0.188:8123")!,
            isAccepting: false,
            onAccept: {},
            onReject: {}
        )
    }
    .navigationViewStyle(.stack)
}

#Preview("Long URL") {
    NavigationView {
        InvitationView(
            invitationURL: URL(
                string: "http://thisisaverylongurlsowecantesthowtheuibehaveswiththisurlwhichisgoingtobesuperlongandimnotgoingtoabletofititanywhere:8123"
            )!,
            isAccepting: false,
            onAccept: {},
            onReject: {}
        )
    }
    .navigationViewStyle(.stack)
}
