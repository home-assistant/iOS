import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct AreaGridButton: View {
    enum Constants {
        static let cornerRadius: CGFloat = DesignSystem.CornerRadius.two
        static let borderLineWidth: CGFloat = DesignSystem.Border.Width.default
        static let iconSize: CGFloat = 32
    }

    let section: HomeViewModel.RoomSection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                icon
                Text(section.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(uiColor: .label))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spaces.one)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(Color.tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(Color.tileBorder, lineWidth: Constants.borderLineWidth)
            )
        }
    }

    private var icon: some View {
        let materialDesignIcon = MaterialDesignIcons(
            serversideValueNamed: section.icon.orEmpty,
            fallback: .squareRoundedOutlineIcon
        )
        return Group {
            Image(uiImage: materialDesignIcon.image(
                ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                color: .haPrimary
            ))
        }
        .font(.system(size: Constants.iconSize))
    }
}
