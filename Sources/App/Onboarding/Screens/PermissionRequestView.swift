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
    let showSkipButton: Bool
    let continueAction: () -> Void
    let dismissAction: (() -> Void)?

    @State private var accentColor: UIColor = Asset.Colors.haPrimary.color
    var body: some View {
        VStack {
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
            VStack(spacing: Spaces.two) {
                Button {
                    continueAction()
                } label: {
                    Text(L10n.continueLabel)
                }
                .buttonStyle(HAButtonStyle())
                if showSkipButton {
                    Button {
                        dismissAction?()
                        dismiss()
                    } label: {
                        Text(L10n.Permission.Screen.Bluetooth.secondaryButton)
                    }
                    .buttonStyle(HASecondaryButtonStyle())
                }
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
        showSkipButton: true
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
struct HASecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(Color.asset(Asset.Colors.haPrimary))
            .frame(maxWidth: .infinity)
            .frame(height: 55)
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
