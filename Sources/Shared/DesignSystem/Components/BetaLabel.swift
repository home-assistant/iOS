import SwiftUI

public struct BetaLabel: View {
    public init() {}
    public var body: some View {
        Text("BETA")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .clipShape(Capsule())
    }
}

#Preview {
    BetaLabel()
}
