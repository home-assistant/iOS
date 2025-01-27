import SFSafeSymbols
import Shared
import SwiftUI

struct TileCard: View {
    struct Content {
        let title: String
        let subtitle: String?
        let image: Image
    }

    let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                content.image
                VStack {
                    Text(content.title)
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let subtitle = content.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 55)
        .background(Color.asset(Asset.Colors.tileBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.asset(Asset.Colors.tileBorder), lineWidth: 1)
        }
    }
}

#Preview {
    VStack {
        LazyVGrid(columns: [GridItem(), GridItem()]) {
            TileCard(content: .init(title: "Title", subtitle: "Subtitle", image: Image(systemSymbol: .plus)))
            TileCard(content: .init(title: "Title", subtitle: "Subtitle", image: Image(systemSymbol: .xmark)))
            TileCard(content: .init(title: "Title", subtitle: nil, image: Image(systemSymbol: .heart)))
            TileCard(content: .init(title: "Title", subtitle: "Subtitle", image: Image(systemSymbol: .plus)))
            TileCard(content: .init(title: "Title", subtitle: "Subtitle", image: Image(systemSymbol: .plus)))
            TileCard(content: .init(title: "Title", subtitle: "Subtitle", image: Image(systemSymbol: .plus)))
            TileCard(content: .init(title: "Title", subtitle: nil, image: Image(systemSymbol: .plus)))
        }
        .padding(Spaces.one)
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .background(Color.asset(Asset.Colors.primaryBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.2), radius: 10)
    .padding()
}
