import Shared
import SwiftUI

/// The spinner a camera player shows while its stream connects.
///
/// Centered on the stream, which fills the screen, rather than between safe areas that are uneven on
/// some devices, such as iPhone Duo around its camera.
struct CameraStreamLoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}

#Preview {
    CameraStreamLoadingView()
        .background(.black)
}
