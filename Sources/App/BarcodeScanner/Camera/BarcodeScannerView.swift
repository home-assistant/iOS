import Shared
import SwiftUI

struct BarcodeScannerView: View {
    static let cameraSquareSize: CGFloat = 320

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BarcodeScannerViewModel
    // Use single data model so both camera previews use same camera stream
    @StateObject private var cameraDataModel = BarcodeScannerDataModel()
    private let flashlightIcon = MaterialDesignIcons.flashlightIcon.image(
        ofSize: .init(width: 24, height: 24),
        color: .white
    )

    private let title: String
    private let description: String
    private let alternativeOptionLabel: String?

    init(
        title: String,
        description: String,
        alternativeOptionLabel: String? = nil,
        incomingMessageId: Int
    ) {
        self.title = title
        self.description = description
        self.alternativeOptionLabel = alternativeOptionLabel
        self._viewModel = .init(wrappedValue: .init(incomingMessageId: incomingMessageId))
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
            cameraDataModel.delegate = viewModel
        }
        .onDisappear {
            cameraDataModel.turnOffFlashlight()
        }
    }

    private var topInformation: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                ModalCloseButton(tint: .white) {
                    viewModel.aborted(.canceled)
                    dismiss()
                }
                .accessibilityHint(.init(L10n.closeLabel))
            }
            Group {
                Text(title)
                    .padding(.top)
                    .font(DesignSystem.Font.title2.bold())
                Text(description)
                    .font(DesignSystem.Font.subheadline)
            }
            .foregroundColor(.white)

            if let alternativeOptionLabel {
                Button {
                    viewModel.aborted(.alternativeOptions)
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
        GeometryReader { proxy in
            BarcodeScannerCameraView(screenSize: proxy.size, model: cameraDataModel)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .overlay {
                    Color.black.opacity(0.8)
                }
        }
    }

    private var cameraSquare: some View {
        // No size needs to be provided here since it wont forward to rectOfInterest
        BarcodeScannerCameraView(screenSize: .zero, model: cameraDataModel, shouldStartCamera: false)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .mask {
                RoundedRectangle(cornerSize: CGSize(width: 20, height: 20))
                    .frame(
                        width: BarcodeScannerView.cameraSquareSize,
                        height: BarcodeScannerView.cameraSquareSize
                    )
            }
            .overlay {
                RoundedRectangle(cornerSize: CGSize(width: 20, height: 20))
                    .stroke(Color.clear, lineWidth: 1)
                    .frame(
                        width: BarcodeScannerView.cameraSquareSize,
                        height: BarcodeScannerView.cameraSquareSize
                    )
            }
            .shadow(color: .haPrimary.opacity(0.8), radius: 10, x: 0, y: 0)
            .overlay {
                VStack {
                    Spacer()
                    Button(action: {
                        cameraDataModel.toggleFlashlight()
                    }, label: {
                        Image(uiImage: flashlightIcon)
                            .padding()
                            .background(Color(uiColor: .init(hex: "#384956")))
                            .mask(Circle())
                            .padding([.trailing, .bottom], DesignSystem.Spaces.two)
                    })
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(
                    width: BarcodeScannerView.cameraSquareSize,
                    height: BarcodeScannerView.cameraSquareSize
                )
            }
    }
}

#Preview {
    BarcodeScannerView(title: "Scan QR-code", description: "Find the code on your device", incomingMessageId: 1)
}

final class BarcodeScannerHostingController: UIHostingController<BarcodeScannerView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait]
    }
}
