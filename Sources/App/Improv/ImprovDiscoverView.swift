import CoreBluetooth
import Improv_iOS
import NetworkExtension
import Shared
import SwiftUI

struct ImprovDiscoverView<Manager>: View where Manager: ImprovManagerProtocol {
    enum ViewState: Equatable {
        case empty
        case list
        case loading(_ message: String)
        case success
        case failure(_ message: String)
    }

    @StateObject private var improvManager: Manager
    private let deviceName: String?

    @State private var state: ViewState = .empty

    @State private var ssid = ""
    @State private var password = ""
    @State private var showWifiAlert = false

    /// Device which is currently selected for connection and wifi operations
    @State private var selectedPeripheral: CBPeripheral?
    @State private var readyToSendWifiCredentials = false
    @State private var bottomSheetState: AppleLikeBottomSheetViewState?

    /// Redirect user to integrations page based on urlPath received from Improv
    private let redirectRequest: (_ urlPath: String) -> Void

    // swiftlint: disable force_cast
    init(
        improvManager: any ImprovManagerProtocol,
        deviceName: String?,
        redirectRequest: @escaping (_ urlPath: String) -> Void
    ) {
        self._improvManager = .init(wrappedValue: improvManager as! Manager)
        self.deviceName = deviceName
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
        .onChange(of: state) { _ in
            if state == .success {
                notifyFrontend()
            }
        }
        .onChange(of: improvManager.deviceState) { newValue in
            switch newValue {
            case .authorizationRequired:
                state = .loading(CoreStrings.componentImprovBleConfigProgressAuthorize)
            case .authorized:
                guard readyToSendWifiCredentials else { return }
                state = .loading(L10n.Improv.ConnectionState.authorized)
                // Sending wifi credentials to device
                authenticate()
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
                readyToSendWifiCredentials = false
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
        .onChange(of: improvManager.foundDevices) { newValue in
            guard let deviceName, selectedPeripheral == nil else { return }
            if let device = newValue.first(where: { $0.value.name == deviceName })?.value {
                selectPeripheral(device)
            } else if state == .empty {
                state = .list
            }
        }
        .alert(L10n.Improv.Wifi.Alert.title, isPresented: $showWifiAlert) {
            TextField(L10n.Improv.Wifi.Alert.ssidPlaceholder, text: $ssid)
                .textInputAutocapitalization(.never)
            SecureField(L10n.Improv.Wifi.Alert.passwordPlaceholder, text: $password)
            Button(L10n.Improv.Wifi.Alert.connectButton, action: connectToDevice)
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
            case .empty:
                // Nothing visible while auto connecting
                loadingView("")
            case .list:
                devicesList
            case let .loading(message):
                loadingView(message)
            case .success:
                successView
            case let .failure(message):
                ImprovFailureView(message: message) {
                    if let selectedPeripheral {
                        improvManager.disconnectFromDevice(selectedPeripheral)
                        state = .list
                    }
                }
            }
        }
    }

    private func notifyFrontend() {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise).done { controller in
            controller.webViewExternalMessageHandler.sendExternalBus(message: .init(
                command: WebViewExternalBusOutgoingMessage.improvDiscoveredDeviceSetupDone.rawValue
            ))
        }
    }

    private func selectPeripheral(_ peripheral: CBPeripheral) {
        selectedPeripheral = peripheral

        // This only works if location permission is permitted
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            if let ssid = hotspotNetwork?.ssid, self.ssid.isEmpty {
                self.ssid = ssid
            }
        }
        showWifiAlert = true
        state = .loading(L10n.Improv.State.connecting)
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
                            selectPeripheral(peripheral)
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

    private func connectToDevice() {
        guard let selectedPeripheral else {
            Current.Log.error("No peripheral selected")
            return
        }
        readyToSendWifiCredentials = true
        improvManager.connectToDevice(selectedPeripheral)
    }

    private func authenticate() {
        state = .loading(L10n.Improv.State.connecting)
        if let error = improvManager.sendWifi(ssid: ssid, password: password) {
            Current.Log.error("Failed to send wifi credentials to Improv device, error: \(error)")
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
        bottomSheetState = .dismiss
    }
}

#Preview {
    ZStack {
        VStack {}
            .background(.blue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        ImprovDiscoverView<ImprovManager>(
            improvManager: ImprovManager.shared,
            deviceName: "12345",
            redirectRequest: { _ in }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
