import Shared
import SwiftUI

struct AdditionalRequestHeadersSection: View {
    @Binding var headers: [AdditionalRequestHeader]
    let addAction: () -> Void
    let removeAction: (AdditionalRequestHeader.ID) -> Void

    var body: some View {
        Section {
            ForEach($headers) { $header in
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                    TextField(
                        L10n.Settings.ConnectionSection.AdditionalRequestHeaders.Name.placeholder,
                        text: $header.name
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    SecureField(
                        L10n.Settings.ConnectionSection.AdditionalRequestHeaders.Value.placeholder,
                        text: $header.value
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    HStack {
                        if !header.name.isEmpty,
                           !AdditionalRequestHeader.isAllowedName(header.normalizedName) {
                            Text(L10n.Settings.ConnectionSection.AdditionalRequestHeaders.invalidName)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            removeAction(header.id)
                        } label: {
                            Image(systemSymbol: .trash)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L10n.Settings.ConnectionSection.AdditionalRequestHeaders.remove)
                    }
                }
            }

            Button(action: addAction) {
                Label(
                    L10n.Settings.ConnectionSection.AdditionalRequestHeaders.add,
                    systemSymbol: .plusCircle
                )
            }
        } header: {
            Text(L10n.Settings.ConnectionSection.AdditionalRequestHeaders.header)
        } footer: {
            Text(L10n.Settings.ConnectionSection.AdditionalRequestHeaders.footer)
        }
    }
}

#Preview {
    List {
        AdditionalRequestHeadersSection(
            headers: .constant([
                AdditionalRequestHeader(name: "CF-Access-Client-Id", value: "example.access"),
                AdditionalRequestHeader(name: "CF-Access-Client-Secret", value: "secret"),
            ]),
            addAction: {},
            removeAction: { _ in }
        )
    }
}
