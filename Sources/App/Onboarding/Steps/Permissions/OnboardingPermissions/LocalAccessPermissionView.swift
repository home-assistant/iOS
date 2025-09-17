import Shared
import SwiftUI

struct LocalAccessPermissionView: View {
    let completeAction: () -> Void
    @State private var selection: String? = "share"

    var body: some View {
        BasePermissionView(
            illustration: {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.secondary)
                    .overlay(
                        Text("Illustration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
                    .padding(.top, DesignSystem.Spaces.four)
            },
            title: "Let us help secure your remote connection",
            primaryDescription: "If this app knows when you’re away from home, it can choose a more secure way to connect to your Home Assistant system. This requires location services to be enabled.",
            secondaryDescription: nil,
            primaryActionTitle: "Next",
            primaryAction: {
                // Handle selection and continue
                completeAction()
            },
            secondaryActionTitle: nil,
            secondaryAction: nil
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LocalAccessPermissionView() {}
}
