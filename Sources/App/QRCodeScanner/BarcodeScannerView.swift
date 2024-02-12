import CodeScanner
import Shared
import SwiftUI

enum QRScannerResult {
    case cancelled
    case alternativeOption
    case success(_ code: String, _ format: String)
}

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    // Use single data model so both camera previews use same camera stream
    @State private var cameraDataModel = BarcodeScannerDataModel()
    private let cameraSquareSize: CGFloat = 320
    private let flashlightIcon = MaterialDesignIcons.flashlightIcon.image(
        ofSize: .init(width: 24, height: 24),
        color: .white
    )

    private let title: String
    private let description: String
    private let alternativeOptionLabel: String?
    private let completion: (QRScannerResult) -> Void

    init(
        title: String,
        description: String,
        alternativeOptionLabel: String? = nil,
        completion: @escaping (QRScannerResult) -> Void
    ) {
        self.title = title
        self.description = description
        self.alternativeOptionLabel = alternativeOptionLabel
        self.completion = completion
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                cameraBackground
                cameraSquare
            }
            .ignoresSafeArea()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)

            topInformation
        }
        .onAppear {
            cameraDataModel.camera.qrFound = { code, format in
                self.completion(.success(code, format))
                self.dismiss()
            }
        }
    }

    private var topInformation: some View {
        VStack(spacing: 8) {
            Button(action: {
                completion(.cancelled)
                dismiss()
            }, label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            })
            .accessibilityHint(.init(L10n.closeLabel))
            Group {
                Text(title)
                    .padding(.top)
                    .font(.title2)
                Text(description)
                    .font(.subheadline)
            }
            .foregroundColor(.white)

            if let alternativeOptionLabel {
                Button {
                    completion(.alternativeOption)
                    dismiss()
                } label: {
                    Text(alternativeOptionLabel)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                .padding(.top)
            }
        }
        .padding()
    }

    private var cameraBackground: some View {
        BarcodeScannerCameraView(model: cameraDataModel)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .overlay {
                Color.black.opacity(0.8)
            }
    }

    private var cameraSquare: some View {
        BarcodeScannerCameraView(model: cameraDataModel, shouldStartCamera: false)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .mask {
                RoundedRectangle(cornerSize: CGSize(width: 20, height: 20))
                    .frame(width: cameraSquareSize, height: cameraSquareSize)
            }
            .overlay {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerSize: CGSize(width: 20, height: 20))
                        .stroke(Color.blue, lineWidth: 1)
                        .frame(width: cameraSquareSize, height: cameraSquareSize)
                    Button(action: {
                        toggleFlashlight()
                    }, label: {
                        Image(uiImage: flashlightIcon)
                            .padding()
                            .background(Color(uiColor: .init(hex: "#384956")))
                            .mask(Circle())
                            .offset(x: -22, y: -22)
                    })
                }
            }
    }

    private func toggleFlashlight() {
        cameraDataModel.toggleFlashlight()
    }
}

#Preview {
    BarcodeScannerView(title: "Scan QR-code", description: "Find the code on your device", completion: { _ in })
}

class BarcodeScannerHostingController: UIHostingController<BarcodeScannerView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait]
    }
}
