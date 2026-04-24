import SwiftUI

/// A SwiftUI replacement for `ButtonRowWithLoading`. Shows a progress indicator
/// while `isLoading` is true and disables user interaction while loading.
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    init(title: String, isLoading: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.accentColor)
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(isLoading)
    }
}
