#if !os(watchOS)
import SwiftUI

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
