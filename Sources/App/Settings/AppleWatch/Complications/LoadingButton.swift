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
                LoadingButtonLabel(title: title)
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

/// Reads `\.isEnabled` so the title color matches the system tint when enabled
/// and dims to `.secondary` when disabled, mirroring the system Button look.
private struct LoadingButtonLabel: View {
    let title: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Text(title)
            .foregroundColor(isEnabled ? .accentColor : .secondary)
    }
}
