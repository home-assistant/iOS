#if os(iOS) && !targetEnvironment(macCatalyst)
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct SpatialScannerViewModelTests {
    @MainActor
    @Test func prepareScanWithoutServerPresentsAnError() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager()

        let viewModel = makeViewModel()
        viewModel.prepareScan()

        #expect(viewModel.isShowingError)
        #expect(viewModel.errorMessage == L10n.SpatialScanner.Error.noServer)
        #expect(viewModel.isPreparing == false)
    }

    @MainActor
    @Test func preflightFailureStopsBeforeRequestingCameraAccess() async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)

        var cameraWasRequested = false
        let viewModel = SpatialScannerViewModel(
            preflight: { _ in throw TestError.any },
            upload: { _, _, _ in throw TestError.any },
            cameraAccess: {
                cameraWasRequested = true
                return true
            }
        )
        viewModel.prepareScan()
        await drainTasks()

        #expect(cameraWasRequested == false)
        #expect(viewModel.isShowingError)
        #expect(viewModel.isPreparing == false)
        #expect(viewModel.isCapturePresented == false)
    }

    @MainActor
    @Test func successfulPreparationPresentsCapture() async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)

        let viewModel = SpatialScannerViewModel(
            preflight: { _ in 4096 },
            upload: { _, _, _ in throw TestError.any },
            cameraAccess: { true }
        )
        viewModel.prepareScan()
        await drainTasks()

        #expect(viewModel.isPreparing == false)
        #expect(viewModel.isCapturePresented)
        #expect(viewModel.isScanning)
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.capturedRoom == nil)
    }

    @MainActor
    @Test func deniedCameraAccessDoesNotPresentCapture() async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)

        let viewModel = SpatialScannerViewModel(
            preflight: { _ in 4096 },
            upload: { _, _, _ in throw TestError.any },
            cameraAccess: { false }
        )
        viewModel.prepareScan()
        await drainTasks()

        #expect(viewModel.errorMessage == L10n.SpatialScanner.cameraDenied)
        #expect(viewModel.isShowingError)
        #expect(viewModel.isPreparing == false)
        #expect(viewModel.isCapturePresented == false)
        #expect(viewModel.isScanning == false)
    }

    @MainActor
    @Test func captureFailureAndDismissResetCaptureState() {
        let viewModel = makeViewModel()
        viewModel.isCapturePresented = true
        viewModel.isScanning = true
        viewModel.finishScan()

        #expect(viewModel.isScanning == false)
        #expect(viewModel.isProcessing)

        viewModel.didFailCapture(error: TestError.any)
        #expect(viewModel.isCapturePresented == false)
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.isShowingError)

        viewModel.isUploading = true
        viewModel.dismissCapture()
        #expect(viewModel.isScanning == false)
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.isUploading == false)
    }

    @MainActor
    private func makeViewModel() -> SpatialScannerViewModel {
        SpatialScannerViewModel(
            preflight: { _ in 4096 },
            upload: { _, _, _ in throw TestError.any },
            cameraAccess: { true }
        )
    }

    private func drainTasks() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    private enum TestError: Error {
        case any
    }
}
#endif
