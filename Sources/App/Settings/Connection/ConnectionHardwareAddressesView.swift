import Shared
import SwiftUI

/// The router hardware addresses that also mark the phone as being at home, kept off the internal URL
/// screen because most setups only ever need the Wi-Fi name. Edits are saved from that screen.
struct ConnectionHardwareAddressesView: View {
    @ObservedObject var viewModel: ConnectionURLViewModel

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .routerWirelessIcon,
                title: L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.title,
                subtitle: L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.footer
            )
            Section {
                ForEach(viewModel.hardwareAddresses.indices, id: \.self) { index in
                    HStack {
                        TextField("aa:bb:cc:dd:ee:ff", text: $viewModel.hardwareAddresses[index])
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        Button(action: { viewModel.removeHardwareAddress(at: index) }) {
                            Image(systemSymbol: .minusCircleFill)
                                .foregroundColor(.red)
                        }
                    }
                }
                .onDelete { indexSet in
                    viewModel.removeHardwareAddresses(at: indexSet)
                }

                Button(action: viewModel.addHardwareAddress) {
                    Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.addNewSsid)
                }
            } header: {
                Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.header)
            }
        }
    }
}

#Preview {
    NavigationView {
        ConnectionHardwareAddressesView(
            viewModel: ConnectionURLViewModel(server: ServerFixture.standard, urlType: .internal)
        )
    }
    .navigationViewStyle(.stack)
}
