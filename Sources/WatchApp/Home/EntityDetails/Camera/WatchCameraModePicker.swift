import Shared
import SwiftUI

/// The stream picker under a camera, shown only when both MJPEG and HLS work for that camera.
///
/// Hand-built rather than a `Picker`: watchOS has no segmented picker style, and its other styles
/// (a wheel, or a row that pushes another screen) are far too much for a two-option switch sitting
/// under a live image.
struct WatchCameraModePicker: View {
    let modes: [WatchCameraViewModel.Mode]
    @Binding var selection: WatchCameraViewModel.Mode

    var body: some View {
        HStack(spacing: .zero) {
            ForEach(modes) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(verbatim: mode.title)
                        .font(.caption2.weight(selection == mode ? .semibold : .regular))
                        .foregroundStyle(selection == mode ? Color.black : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spaces.half)
                        .background(
                            Capsule()
                                .fill(selection == mode ? Color.white : Color.clear)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spaces.half)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
        )
        .animation(.easeInOut(duration: 0.15), value: selection)
    }
}

#if DEBUG
#Preview {
    WatchCameraModePicker(
        modes: WatchCameraViewModel.Mode.allCases,
        selection: .constant(.mjpeg)
    )
    .padding()
    .background(Color.black)
}
#endif
