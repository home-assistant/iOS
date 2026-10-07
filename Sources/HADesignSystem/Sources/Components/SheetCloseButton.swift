#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// The close button of a sheet, which reports the tap rather than dismissing on its own.
///
/// Frontend counterpart: `ha-icon-button` carrying `mdiClose`, as every close affordance there is.
/// Distinct from ``ModalCloseButton`` only in who owns the dismissal.
public struct SheetCloseButton: View {
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            Image(systemSymbol: .xmark)
        }
        .font(.title2)
        .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

#Preview {
    SheetCloseButton(action: {})
}

extension SheetCloseButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-icon-button" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
