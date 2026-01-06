import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeViewCustomizationView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Unavailable")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        CloseButton {
                            dismiss()
                        }
                    }
                }
        }
    }
}
