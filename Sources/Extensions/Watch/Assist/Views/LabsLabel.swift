import Shared
import SwiftUI

struct LabsLabel: View {
    private enum Constants {
        static let iconSize: CGFloat = 15
    }

    var body: some View {
        HStack(spacing: .zero) {
            Image(uiImage: MaterialDesignIcons.testTubeIcon.image(
                ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                color: .white
            ))
            .padding(.leading, DesignSystem.Spaces.one)

            Text(verbatim: "Labs")
                .font(.caption2.bold())
                .padding(.leading, DesignSystem.Spaces.half)
                .padding(.trailing, DesignSystem.Spaces.one)
        }
        .foregroundColor(.white)
        .padding(.vertical, DesignSystem.Spaces.half)
        .background(Color.orange)
        .clipShape(Capsule())
    }
}

#Preview {
    LabsLabel()
        .padding()
}
