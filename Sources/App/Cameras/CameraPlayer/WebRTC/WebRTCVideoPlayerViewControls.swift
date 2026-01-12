import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 16.0, *)
struct WebRTCVideoPlayerViewControls: View {
    let cameraName: String?
    let close: () -> Void
    let isMuted: Bool
    let toggleMute: () -> Void

    @State private var showKnownIssuesSheet = false

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    if let cameraName {
                        Text(cameraName)
                            .font(DesignSystem.Font.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    topButtons
                }
                Spacer()
                knownIssuesButton
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [
                    .black, .clear, .black,
                ], startPoint: .top, endPoint: .bottom
            )
            .opacity(0.5)
        )
        .sheet(isPresented: $showKnownIssuesSheet) {
            KnownIssuesSheet()
        }
    }

    @ViewBuilder
    private var knownIssuesButton: some View {
        Button {
            showKnownIssuesSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemSymbol: .infoCircle)
                    .font(.footnote)
                Text(L10n.WebrtcPlayer.KnownIssues.title)
                    .font(DesignSystem.Font.footnote.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .modify { view in
                if #available(iOS 26.0, *) {
                    view.glassEffect(.clear.interactive())
                } else {
                    view
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var topButtons: some View {
        Button(action: toggleMute) {
            Image(systemSymbol: isMuted ? .speakerSlashFill : .speakerWave3)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white)
                .padding(DesignSystem.Spaces.oneAndHalf)
                .modify { view in
                    if #available(iOS 26.0, *) {
                        view.glassEffect(.clear.interactive(), in: .circle)
                    } else {
                        view
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
        }
        .buttonStyle(.plain)
        ModalCloseButton(tint: .white) {
            close()
        }
        .padding(16)
    }
}

@available(iOS 16.0, *)
private struct KnownIssuesSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.WebRTCPlayer.Experimental.disclaimer)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(L10n.WebrtcPlayer.KnownIssues.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.doneLabel) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

@available(iOS 16.0, *)
#Preview {
    WebRTCVideoPlayerViewControls(
        cameraName: "Living Room Camera",
        close: {},
        isMuted: false,
        toggleMute: {}
    )
}

@available(iOS 16.0, *)
#Preview("Known Issues Sheet") {
    KnownIssuesSheet()
}
