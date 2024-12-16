import SFSafeSymbols
import SwiftUI

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
