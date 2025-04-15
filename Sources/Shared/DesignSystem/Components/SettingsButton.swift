import SwiftUI

public struct SettingsButton: View {
    private let action: () -> Void
    private let tint: Color

    public init(tint: Color = Color.gray, action: @escaping (() -> Void)) {
        self.action = action
        self.tint = tint
    }

    public var body: some View {
        Button(action: {
            action()
        }, label: {
            Image(
                uiImage: MaterialDesignIcons.cogIcon.image(
                    ofSize: .init(width: 25, height: 25), color: UIColor(tint)
                )
            )
        })
    }
}

#Preview {
    VStack {
        SettingsButton {}
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        Spacer()
    }
}
