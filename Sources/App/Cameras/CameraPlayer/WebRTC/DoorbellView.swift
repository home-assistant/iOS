import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 18.0, *)
struct DoorbellView: View {
    @Environment(\.dismiss) var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?
    private let onWebRTCUnsupported: (() -> Void)?
    private let onSnapshot: (() -> Void)?
    private let onUnlock: (() -> Void)?

    @State private var isSnapshotLoading: Bool = false
    @State private var showToast: Bool = false

    init(
        server: Server,
        cameraEntityId: String,
        cameraName: String? = nil,
        onWebRTCUnsupported: (() -> Void)? = nil,
        onSnapshot: (() -> Void)? = nil,
        onUnlock: (() -> Void)? = nil
    ) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
        self.onWebRTCUnsupported = onWebRTCUnsupported
        self.onSnapshot = onSnapshot
        self.onUnlock = onUnlock
    }

    var body: some View {
        NavigationView {
            controlsOverlay
                .background(videoBackground)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {}, label: {
                            Image(systemSymbol: .cameraFill)
                        })
                        .tint(.haPrimary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        CloseButton {
                            dismiss()
                        }
                    }
                }
        }
    }

    // MARK: - View Components

    private var videoBackground: some View {
        ZStack {
            MeshGradient(
                width: 2,
                height: 2,
                points: [
                    [0, 0], [1, 0],
                    [0, 1], [1, 1],
                ],
                colors: [
                    .purple, .mint,
                    .orange, .blue,
                ]
            )
            .ignoresSafeArea()
            Image(.brunoMemoji)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200)
        }
    }

    private var controlsOverlay: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Text(cameraName ?? cameraEntityId)
                .font(.headline.bold())
                .padding(.horizontal)
                .padding(.vertical, DesignSystem.Spaces.one)
                .modify { view in
                    if #available(iOS 26.0, *) {
                        view.glassEffect(.regular.interactive(), in: .capsule)
                    } else {
                        view
                            .background(.regularMaterial)
                            .clipShape(.capsule)
                    }
                }
            Spacer()
            Button(action: {}, label: {
                Image(systemSymbol: .micFill)
            })
            .buttonStyle(.primaryButton)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DesignSystem.Spaces.four)
        .background(controlOverlayBackground)
    }

    private var controlOverlayBackground: some View {
        VStack {
            LinearGradient(colors: [.clear, .black], startPoint: .bottom, endPoint: .top)
                .frame(height: 200)
            Spacer()
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 200)
        }
        .ignoresSafeArea()
    }

    private var unlockButton: some View {
        Button(action: {}, label: {
            Text("Open door")
        })
        .buttonStyle(.outlinedButton)
    }

    private var snapshotButton: some View {
        Button(action: {}, label: {
            Image(systemSymbol: .cameraFill)
        })
        .buttonStyle(.outlinedButton)
    }
}

@available(iOS 18.0, *)
#Preview {
    DoorbellView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door",
        onSnapshot: { print("Snapshot taken") },
        onUnlock: { print("Unlock pressed") }
    )
}
