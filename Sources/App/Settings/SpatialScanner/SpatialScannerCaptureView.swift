#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

struct SpatialScannerCaptureView: View {
    @ObservedObject var viewModel: SpatialScannerViewModel
    @State private var previousIdleTimerState = false

    var body: some View {
        ZStack {
            RoomPlanCaptureView(
                isScanning: $viewModel.isScanning,
                onCaptured: viewModel.didCapture,
                onError: viewModel.didFailCapture
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        viewModel.dismissCapture()
                    } label: {
                        Label(L10n.SpatialScanner.Capture.cancel, systemSymbol: .xmark)
                            .labelStyle(.iconOnly)
                            .font(.title3.bold())
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(L10n.SpatialScanner.Capture.cancel)
                    Spacer()
                }

                Spacer()

                if viewModel.receipt != nil {
                    Label(L10n.SpatialScanner.Success.title, systemSymbol: .checkmarkCircleFill)
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                } else if viewModel.isProcessing {
                    ProgressView(L10n.SpatialScanner.Capture.processing)
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                } else if viewModel.capturedRoom != nil {
                    HStack {
                        Button(L10n.SpatialScanner.Preview.scanAgain) {
                            viewModel.scanAgain()
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.uploadScan()
                        } label: {
                            if viewModel.isUploading {
                                HStack {
                                    ProgressView()
                                    Text(L10n.SpatialScanner.Preview.sending)
                                }
                            } else {
                                Label(
                                    L10n.SpatialScanner.Preview.send,
                                    systemSymbol: .paperplaneFill
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isUploading)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                } else {
                    VStack(spacing: DesignSystem.Spaces.one) {
                        Text(L10n.SpatialScanner.Capture.guide)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)

                        Button(L10n.SpatialScanner.Capture.done) {
                            viewModel.finishScan()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .onAppear {
            previousIdleTimerState = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: viewModel.isScanning) { isScanning in
            UIApplication.shared.isIdleTimerDisabled = isScanning ? true : previousIdleTimerState
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerState
        }
        .alert(
            L10n.SpatialScanner.Error.title,
            isPresented: $viewModel.isShowingError
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    SpatialScannerCaptureView(viewModel: SpatialScannerViewModel())
}
#endif
