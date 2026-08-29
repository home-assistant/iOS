#if !os(watchOS)
import SwiftUI

/// Presents an ``AppleLikeBottomSheet`` from a button, since a sheet cannot be shown inline the way
/// the other gallery variants are.
///
/// Frontend counterpart: a demo on a `gallery/` page. Gallery scaffolding, not a component.
struct BottomSheetGalleryDemo: View {
    @State private var state: AppleLikeBottomSheetViewState?
    @State private var isPresented = false

    var body: some View {
        Button("Present bottom sheet") {
            isPresented = true
        }
        .buttonStyle(.secondaryButton)
        .fullScreenCover(isPresented: $isPresented) {
            AppleLikeBottomSheet(
                title: "Example sheet",
                content: {
                    Text("This AppleLikeBottomSheet is rendered from the components library.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                },
                state: $state,
                customDismiss: { isPresented = false }
            )
        }
    }
}

#Preview {
    BottomSheetGalleryDemo()
}
#endif
