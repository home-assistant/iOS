import Shared
import SwiftUI

struct OnboardingScanningInstanceRow: View {
    private enum Constants {
        static let iconContainerSize: CGFloat = 60
        static let minHeight: CGFloat = 60
    }

    let name: String
    let internalURLString: String?
    let externalURLString: String?
    let internalOrExternalURLString: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            icon
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text(internalURLString ?? internalOrExternalURLString)
                    .font(DesignSystem.Font.caption)
                    .foregroundColor(.secondary)
                    .privacySensitive()
                if let externalURLString {
                    Text(externalURLString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .privacySensitive()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isLoading {
                HAProgressView(style: .small)
                    .padding(.trailing, DesignSystem.Spaces.one)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: Constants.minHeight)
        .padding(DesignSystem.Spaces.one)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two)
                .stroke(Color.tileBorder, lineWidth: DesignSystem.Border.Width.default)
        )
    }

    private var icon: some View {
        ZStack {
            Image(systemSymbol: .externaldriveConnectedToLineBelow)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.haPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(DesignSystem.Spaces.oneAndHalf)
        }
        .frame(width: Constants.iconContainerSize, height: Constants.iconContainerSize)
    }
}

#Preview {
    List {
        Group {
            OnboardingScanningInstanceRow(
                name: "Home Assistant",
                internalURLString: "https://example.com",
                externalURLString: "https://example.com",
                internalOrExternalURLString: "https://example.com",
                isLoading: true
            )
            OnboardingScanningInstanceRow(
                name: "Home Assistant",
                internalURLString: "https://example.com",
                externalURLString: "https://example.com",
                internalOrExternalURLString: "https://example.com",
                isLoading: false
            )
            OnboardingScanningInstanceRow(
                name: "Home Assistant",
                internalURLString: "https://example.com",
                externalURLString: "https://example.com",
                internalOrExternalURLString: "https://example.com",
                isLoading: false
            )
        }
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
}
