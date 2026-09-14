import SFSafeSymbols
import Shared
import SwiftUI

/// A text-input notification action rendered inside the watch long look, because watchOS never
/// delivers the reply back to the app when the same action is handed to the system
/// (`DynamicNotificationHostingController`).
struct NotificationTextInputActionButton: View {
    let action: NotificationAction
    let state: DynamicNotificationViewModel.TextInputActionState?
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            HStack(spacing: DesignSystem.Spaces.half) {
                Text(action.title)
                    .frame(maxWidth: .infinity, alignment: .leading)

                switch state {
                case .sending:
                    ProgressView()
                case .sent:
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(.green)
                case .failed:
                    Image(systemSymbol: .exclamationmarkTriangle)
                        .foregroundStyle(.red)
                case nil:
                    Image(systemSymbol: .textBubble)
                }
            }
        }
        .disabled(state == .sending || state == .sent)
    }
}

#if DEBUG
#Preview("States") {
    List {
        NotificationTextInputActionButton(
            action: NotificationAction(identifier: "REPLY", title: "Reply", textInput: true),
            state: nil,
            perform: {}
        )
        NotificationTextInputActionButton(
            action: NotificationAction(identifier: "REPLY", title: "Sending", textInput: true),
            state: .sending,
            perform: {}
        )
        NotificationTextInputActionButton(
            action: NotificationAction(identifier: "REPLY", title: "Sent", textInput: true),
            state: .sent,
            perform: {}
        )
        NotificationTextInputActionButton(
            action: NotificationAction(identifier: "REPLY", title: "Failed", textInput: true),
            state: .failed,
            perform: {}
        )
    }
}
#endif
