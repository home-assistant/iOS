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

    @Environment(\.dismiss) private var dismiss
    @StateObject private var improvManager: Manager

    @State private var state: ViewState = .list
    @State private var displayBottomSheet = false

    @State private var ssid = ""
    @State private var password = ""
    @State private var showWifiAlert = false

    @State private var selectedPeripheral: CBPeripheral?

    private let bottomSheetMinHeight: CGFloat = 400
    private let redirectRequest: (_ urlPath: String) -> Void

    // swiftlint: disable force_cast
    init(improvManager: any ImprovManagerProtocol, redirectRequest: @escaping (_ urlPath: String) -> Void) {
        self._improvManager = .init(wrappedValue: improvManager as! Manager)
        self.redirectRequest = redirectRequest
    }

    var body: some View {
        VStack {
            Spacer()
            ZStack(alignment: .top) {
                closeButton
                VStack {
                    switch state {
                    case .list:
                        devicesList
                    case let .loading(message):
                        loadingView(message)
                    case .success:
                        successView
                    case let .failure(message):
                        failureView(message)
                    }
                }
                .padding(.top, Spaces.six)
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal)
            .frame(minHeight: bottomSheetMinHeight)
            .frame(maxWidth: maxWidth, alignment: .center)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: perfectCornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(Spaces.one)
            .fixedSize(horizontal: false, vertical: true)
            .offset(y: displayBottomSheet ? 0 : bottomSheetMinHeight)
            .onAppear {
                withAnimation(.bouncy) {
                    displayBottomSheet = true
                }
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.3))
        .animation(.default, value: state)
        .modify {
            if #available(iOS 16, *) {
                $0.persistentSystemOverlays(.hidden)
            } else {
                $0
            }
        }
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
                showWifiAlert = true
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

    private var maxWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .phone {
            .infinity
        } else {
            600
        }
    }

    private var perfectCornerRadius: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .phone {
            UIScreen.main.displayCornerRadius - Spaces.one
        } else {
            50
        }
    }

    @ViewBuilder
    private var devicesList: some View {
        Text(L10n.Improv.List.title)
            .font(.title.bold())
        List {
            ForEach(improvManager.foundDevices.keys.sorted(), id: \.self) { peripheralKey in
                if let peripheral = improvManager.foundDevices[peripheralKey] {
                    Button {
                        selectedPeripheral = peripheral
                        if improvManager.connectedDevice?.identifier == peripheral.identifier {
                            showWifiAlert = true
                        } else {
                            improvManager.connectToDevice(peripheral)
                            state = .loading(L10n.Improv.State.connecting)
                        }
                    } label: {
                        HStack {
                            Text(peripheral.name ?? peripheral.identifier.uuidString)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right.circle")
                        }
                        .foregroundStyle(Color(uiColor: Asset.Colors.haPrimary.color))
                    }
                }
            }
            Section {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .modify {
            if #available(iOS 16, *) {
                $0.scrollContentBackground(.hidden)
            } else {
                $0
            }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: {
                dismiss()
            }, label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.gray, .white)
            })
        }
        .padding(.top, Spaces.three)
        .padding([.trailing, .bottom], Spaces.one)
    }

    @ViewBuilder
    private var nextButton: some View {
        Button {
            let improvResultDomain = URL(string: improvManager.lastResult?.first ?? "")?.queryItems?["domain"] ?? ""
            let redirectPath = "/config/integrations/dashboard/add?domain=" + improvResultDomain
            redirectRequest(redirectPath)

            if #available(iOS 17.0, *) {
                withAnimation(.bouncy) {
                    displayBottomSheet = false
                } completion: {
                    dismiss()
                }
            } else {
                withAnimation(.bouncy) {
                    displayBottomSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }
            }

        } label: {
            Text(L10n.Improv.Button.continue)
                .foregroundStyle(Color(uiColor: .label))
                .padding()
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.bottom, 32)
    }

    private func authenticate() {
        state = .loading(L10n.Improv.State.connecting)
        if let error = improvManager.sendWifi(ssid: ssid, password: password) {
            Current.Log.error("Failed to send wifi credentials to Improv device, error: \(error)")
            state = .list
        }
    }

    @ViewBuilder
    private func loadingView(_ message: String) -> some View {
        VStack(spacing: Spaces.three) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(.init(floatLiteral: 1.8))
            Text(message)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }

    @ViewBuilder
    private var successView: some View {
        Spacer()
        VStack(spacing: Spaces.two) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white, .green)
            Text(L10n.Improv.State.success)
                .font(.title3.bold())
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        Spacer()
        nextButton
    }

    @ViewBuilder
    private func failureView(_ message: String) -> some View {
        Spacer()
        VStack(spacing: Spaces.two) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white, .red)
            Text(message)
                .multilineTextAlignment(.center)
                .font(.title3.bold())
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        Spacer()
        Button {
            state = .list
        } label: {
            Text(L10n.Improv.Button.continue)
                .padding()
                .foregroundColor(Color(uiColor: .secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
        .padding(.bottom, Spaces.three)
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
