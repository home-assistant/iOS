#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

struct SpatialScannerView: View {
    @StateObject private var viewModel: SpatialScannerViewModel

    init(viewModel: SpatialScannerViewModel = SpatialScannerViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .cubeScanIcon,
                title: L10n.SpatialScanner.title,
                subtitle: L10n.SpatialScanner.intro
            )

            Section {
                if Current.servers.all.count > 1 {
                    ServersPickerPillList(selectedServerId: $viewModel.selectedServerID)
                } else if let server = viewModel.selectedServer {
                    HomeAssistantAccountRowView(server: server)
                } else {
                    Text(L10n.SpatialScanner.Error.noServer)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.SpatialScanner.Server.header)
            } footer: {
                Text(L10n.SpatialScanner.Server.footer)
            }

            Section {
                Button {
                    viewModel.prepareScan()
                } label: {
                    if viewModel.isPreparing {
                        HStack {
                            ProgressView()
                            Text(L10n.SpatialScanner.preparing)
                        }
                    } else {
                        Label(L10n.SpatialScanner.start, systemSymbol: .camera)
                    }
                }
                .disabled(viewModel.isPreparing || viewModel.selectedServer == nil)

                if let receipt = viewModel.receipt {
                    Label {
                        Text(L10n.SpatialScanner.Success.detail(receipt.scanID))
                    } icon: {
                        Image(systemSymbol: .checkmarkCircleFill)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle(L10n.SpatialScanner.title)
        .fullScreenCover(isPresented: $viewModel.isCapturePresented) {
            SpatialScannerCaptureView(viewModel: viewModel)
        }
        .alert(
            L10n.SpatialScanner.Error.title,
            isPresented: $viewModel.isShowingError
        ) {
            if viewModel.errorMessage == L10n.SpatialScanner.cameraDenied {
                Button(L10n.SpatialScanner.Error.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

extension SpatialScannerView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.SpatialScanner.start),
            SettingsSearchEntry(L10n.SpatialScanner.Server.header),
            SettingsSearchEntry(L10n.SpatialScanner.Preview.send),
        ]
    }
}

#Preview {
    NavigationStack {
        SpatialScannerView()
    }
}
#endif
