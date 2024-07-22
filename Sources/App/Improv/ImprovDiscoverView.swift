import CoreBluetooth
import Improv_iOS
import Shared
import SwiftUI

struct ImprovDiscoverView<Manager>: View where Manager: ImprovManagerProtocol {
    enum ViewState: Equatable {
        case list
        case loading(_ message: String)
        case success
        case failure(_ message: String)
    }

    @StateObject private var improvManager: Manager

    @State private var state: ViewState = .list

    @State private var ssid = ""
    @State private var password = ""
    @State private var showWifiAlert = false

    /// Device which is currently selected for connection and wifi operations
    @State private var selectedPeripheral: CBPeripheral?

    @State private var bottomSheetState: AppleLikeBottomSheetViewState?

    /*
     If device is disconnected when user attempts to send wifi credentials
     we ask the device to reconnect and as soon as it is authorized we retry with the same credentials
     */
    @State private var shouldRetryWifiSetup = false

    /// Redirect user to integrations page based on urlPath received from Improv
    private let redirectRequest: (_ urlPath: String) -> Void

    // swiftlint: disable force_cast
    init(improvManager: any ImprovManagerProtocol, redirectRequest: @escaping (_ urlPath: String) -> Void) {
        self._improvManager = .init(wrappedValue: improvManager as! Manager)
        self.redirectRequest = redirectRequest
    }

    var body: some View {
        AppleLikeBottomSheet(
            content: {
                content
            },
            showCloseButton: true,
            state: $bottomSheetState
        )
        .animation(.default, value: state)
        .onAppear {
            if improvManager.bluetoothState == .poweredOn {
                improvManager.scan()
            }
        }
        .onDisappear {
            improvManager.stopScan()
        }
        .onChange(of: improvManager.bluetoothState) { newValue in
            if newValue == .poweredOn {
                improvManager.scan()
            }
        }
        .onChange(of: improvManager.deviceState) { newValue in
            switch newValue {
            case .authorizationRequired:
                state = .loading(L10n.Improv.ConnectionState.autorizationRequired)
            case .authorized:
                state = .loading(L10n.Improv.ConnectionState.authorized)
                if shouldRetryWifiSetup {
                    shouldRetryWifiSetup = false
                    authenticate()
                } else {
                    showWifiAlert = true
                }
            case .provisioned:
                state = .success
            case .provisioning:
                state = .loading(L10n.Improv.ConnectionState.provisioning)
            case .none:
                break
            }
        }
        .onChange(of: improvManager.errorState) { newValue in
            switch newValue {
            case .noError:
                break
            case .invalidRPCPacket:
                state = .failure(L10n.Improv.ErrorState.invalidRpcPacket)
            case .unknownCommand:
                state = .failure(L10n.Improv.ErrorState.unknownCommand)
            case .unableToConnect:
                state = .failure(L10n.Improv.ErrorState.unableToConnect)
            case .notAuthorized:
                state = .failure(L10n.Improv.ErrorState.notAuthorized)
            case .unknown:
                state = .failure(L10n.Improv.ErrorState.unknown)
            case .none:
                break
            }
        }
        .onChange(of: improvManager.connectedDevice) { newValue in
            if newValue == nil || selectedPeripheral == nil {
                state = .list
            } else if newValue?.identifier == selectedPeripheral?.identifier {
                state = .loading(L10n.Improv.State.connected)
            }
        }
        .alert(L10n.Improv.Wifi.Alert.title, isPresented: $showWifiAlert) {
            TextField(L10n.Improv.Wifi.Alert.ssidPlaceholder, text: $ssid)
                .textInputAutocapitalization(.never)
            SecureField(L10n.Improv.Wifi.Alert.passwordPlaceholder, text: $password)
            Button(L10n.Improv.Wifi.Alert.connectButton, action: authenticate)
            Button(L10n.Improv.Wifi.Alert.cancelButton, role: .cancel) {
                cancelWifiInput()
            }
        } message: {
            Text(L10n.Improv.Wifi.Alert.description)
        }
    }

    private var content: some View {
        VStack {
            switch state {
            case .list:
                devicesList
            case let .loading(message):
                loadingView(message)
            case .success:
                successView
            case let .failure(message):
                ImprovFailureView(message: message) {
                    state = .list
                }
            }
        }
    }

    @ViewBuilder
    private var devicesList: some View {
        List {
            Section(content: {
                if improvManager.foundDevices.isEmpty {
                    VStack {}
                }
                ForEach(improvManager.foundDevices.keys.sorted(), id: \.self) { peripheralKey in
                    if let peripheral = improvManager.foundDevices[peripheralKey] {
                        Button {
                            selectedPeripheral = peripheral
                            improvManager.connectToDevice(peripheral)
                            state = .loading(L10n.Improv.State.connecting)
                        } label: {
                            Text(peripheral.name ?? peripheral.identifier.uuidString)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(Color(uiColor: .label))
                        }
                    }
                }
            }, header: {
                HStack(spacing: Spaces.two) {
                    Text(L10n.Improv.List.title)
                        .textCase(.uppercase)
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .multilineTextAlignment(.center)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .listRowBackground(Color.clear)
                    Spacer()
                }
            })
        }
        .modify {
            if #available(iOS 16, *) {
                $0.scrollContentBackground(.hidden)
            } else {
                $0
            }
        }
    }

    private func authenticate() {
        state = .loading(L10n.Improv.State.connecting)
        if let error = improvManager.sendWifi(ssid: ssid, password: password) {
            Current.Log.error("Failed to send wifi credentials to Improv device, error: \(error)")
            state = .list
            guard let selectedPeripheral else { return }
            shouldRetryWifiSetup = true
            improvManager.connectToDevice(selectedPeripheral)
        }
    }

    @ViewBuilder
    private func loadingView(_ message: String) -> some View {
        VStack(spacing: Spaces.three) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(.init(floatLiteral: 1.8))
            Text(message)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Spacer()
        }
    }

    @ViewBuilder
    private var successView: some View {
        ImprovSuccessView {
            let improvResultDomain = URL(string: improvManager.lastResult?.first ?? "")?.queryItems?["domain"] ?? ""
            let redirectPath = "/config/integrations/dashboard/add?domain=" + improvResultDomain
            redirectRequest(redirectPath)
            bottomSheetState = .dismiss
        }
    }

    private func cancelWifiInput() {
        if let selectedPeripheral {
            improvManager.disconnectFromDevice(selectedPeripheral)
            self.selectedPeripheral = nil
        }
        state = .list
    }
}

#Preview {
    ZStack {
        VStack {}
            .background(.blue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        ImprovDiscoverView<ImprovManager>(improvManager: ImprovManager.shared, redirectRequest: { _ in })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
