#if os(iOS) && !targetEnvironment(macCatalyst)
import AVFoundation
import Foundation
import RoomPlan
import Shared

@MainActor
final class SpatialScannerViewModel: ObservableObject {
    typealias Preflight = (Server) async throws -> Int
    typealias Upload = (SpatialScanPayload, Int, Server) async throws -> SpatialScanReceipt
    typealias CameraAccess = () async -> Bool

    @Published var selectedServerID: String?
    @Published var isCapturePresented = false
    @Published var isScanning = false
    @Published var isProcessing = false
    @Published var isPreparing = false
    @Published var isUploading = false
    @Published var isShowingError = false
    @Published private(set) var capturedRoom: CapturedRoom?
    @Published private(set) var receipt: SpatialScanReceipt?
    @Published private(set) var errorMessage = ""

    private let preflight: Preflight
    private let upload: Upload
    private let cameraAccess: CameraAccess
    private var maxPayloadBytes = 0

    init(
        preflight: @escaping Preflight = SpatialScannerAPI.preflight,
        upload: @escaping Upload = SpatialScannerAPI.upload,
        cameraAccess: @escaping CameraAccess = SpatialScannerViewModel.requestCameraAccess
    ) {
        self.preflight = preflight
        self.upload = upload
        self.cameraAccess = cameraAccess
        self.selectedServerID = Current.servers.all.first?.identifier.rawValue
    }

    var selectedServer: Server? {
        guard let selectedServerID else { return nil }
        return Current.servers.all.first { $0.identifier.rawValue == selectedServerID }
    }

    func prepareScan() {
        guard let server = selectedServer else {
            presentError(L10n.SpatialScanner.Error.noServer)
            return
        }

        isPreparing = true
        Task {
            do {
                maxPayloadBytes = try await preflight(server)
                guard await cameraAccess() else {
                    throw CameraPermissionError.denied
                }
                capturedRoom = nil
                receipt = nil
                isScanning = true
                isProcessing = false
                isCapturePresented = true
            } catch {
                presentError(message(for: error))
            }
            isPreparing = false
        }
    }

    func finishScan() {
        isScanning = false
        isProcessing = true
    }

    func didCapture(room: CapturedRoom) {
        capturedRoom = room
        isProcessing = false
    }

    func didFailCapture(error: Swift.Error) {
        isScanning = false
        isProcessing = false
        isCapturePresented = false
        presentError(message(for: error))
    }

    func uploadScan() {
        guard let capturedRoom, let server = selectedServer else {
            presentError(L10n.SpatialScanner.Error.noServer)
            return
        }

        isUploading = true
        Task {
            do {
                let payload = SpatialScanPayload(room: capturedRoom)
                receipt = try await upload(payload, maxPayloadBytes, server)
            } catch {
                presentError(message(for: error))
            }
            isUploading = false
        }
    }

    func scanAgain() {
        capturedRoom = nil
        receipt = nil
        isProcessing = false
        isScanning = true
    }

    func dismissCapture() {
        isCapturePresented = false
        isScanning = false
        isProcessing = false
        isUploading = false
    }

    private static func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }

    private func message(for error: Swift.Error) -> String {
        if error is CameraPermissionError {
            return L10n.SpatialScanner.cameraDenied
        }
        return L10n.SpatialScanner.Error.generic(error.localizedDescription)
    }

    private enum CameraPermissionError: Swift.Error {
        case denied
    }
}
#endif
