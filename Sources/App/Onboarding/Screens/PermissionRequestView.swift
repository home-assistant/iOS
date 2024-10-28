import Shared
import SwiftUI
import UIKit

struct PermissionRequestView: View {
    @Environment(\.dismiss) private var dismiss
    struct Reason {
        var id: String = UUID().uuidString
        let icon: MaterialDesignIcons
        let text: String
    }

    let icon: MaterialDesignIcons
    let title: String
    let subtitle: String
    let reasons: [Reason]
    let showCloseButton: Bool
    let continueAction: () -> Void
    let dismissAction: (() -> Void)?

    @State private var accentColor: UIColor = Asset.Colors.haPrimary.color
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: Spaces.two) {
                        Image(uiImage: icon.image(
                            ofSize: .init(width: 100, height: 100), color: accentColor
                        ))
                        Text(title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .multilineTextAlignment(.center)
                        reasonsList
                    }
                    .padding()
                    .padding(.top, Spaces.four)
                }
                if showCloseButton {
                    Button {
                        dismissAction?()
                        dismiss()
                    } label: {
                        Image(systemSymbol: .xmarkCircleFill)
                            .tint(Color(uiColor: .tertiaryLabel))
                            .font(.title)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding([.trailing, .top])
                }
            }
            VStack(spacing: Spaces.two) {
                Button {
                    continueAction()
                } label: {
                    Text(L10n.continueLabel)
                }
                .buttonStyle(HAButtonStyle())
                Button {
                    /* no-op */
                } label: {
                    Text(L10n.Onboarding.Permissions.changeLaterNote)
                }
                .buttonStyle(HALinkButtonStyle())
            }
            .padding()
        }
    }

    private var reasonsList: some View {
        VStack(alignment: .leading) {
            ForEach(reasons, id: \.id) { reason in
                makeReasonItem(reason: reason)
            }
        }
        .padding(.top)
    }

    private func makeReasonItem(reason: Reason) -> some View {
        HStack(spacing: Spaces.two) {
            Image(uiImage: reason.icon.image(
                ofSize: .init(width: 30, height: 30), color: accentColor
            ))
            Text(reason.text)
                .font(.body.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PermissionRequestView(
        icon: .bluetoothIcon,
        title: "Bluetooth",
        subtitle: "Allow to auto discover devices using your device's bluetooth.",
        reasons: [
            .init(
                icon: .accessPointIcon,
                text: "Configure Improv devices"
            ),
        ],
        showCloseButton: true
    ) {} dismissAction: {}
}

struct HAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(Color.asset(Asset.Colors.haPrimary))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HALinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundColor(Color.asset(Asset.Colors.haPrimary))
            .frame(maxWidth: .infinity)
    }
}
