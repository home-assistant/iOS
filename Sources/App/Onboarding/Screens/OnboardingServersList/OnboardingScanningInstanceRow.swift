import Shared
import SwiftUI

struct OnboardingScanningInstanceRow: View {
    let name: String
    let internalURLString: String?
    let externalURLString: String?
    let internalOrExternalURLString: String
    let isLoading: Bool

    var body: some View {
        HStack {
            icon
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text(internalURLString ?? internalOrExternalURLString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let externalURLString {
                    Text(externalURLString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isLoading {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var icon: some View {
        ZStack {
            Image(uiImage: Asset.logo.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .padding(.trailing, Spaces.one)
            if internalURLString == nil, externalURLString != nil {
                Image(systemSymbol: .icloudCircleFill)
                    .foregroundStyle(Color.haPrimary, .white)
                    .offset(x: 8, y: 12)
                    .shadow(color: .black.opacity(0.2), radius: 5)
            }
        }
    }
}

#Preview {
    List {
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
}
