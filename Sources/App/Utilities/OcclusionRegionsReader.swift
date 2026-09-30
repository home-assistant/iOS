import SwiftUI
import UIKit

/// Reports how far hardware cutouts such as the camera reach into a view from its sides.
struct OcclusionRegionsReader: UIViewRepresentable {
    @Binding var insets: EdgeInsets

    func makeUIView(context: Context) -> OcclusionRegionsReaderView {
        OcclusionRegionsReaderView()
    }

    func updateUIView(_ view: OcclusionRegionsReaderView, context: Context) {
        view.onChange = { value in
            DispatchQueue.main.async {
                insets = value
            }
        }
    }
}

#Preview {
    Text("Steps clear of the camera")
        .frame(maxWidth: .infinity)
        .padding()
        .background(OcclusionRegionsReader(insets: .constant(EdgeInsets())))
}
