import SFSafeSymbols
import Shared
import SwiftUI

struct EntityRowView: View {
    // This avoids lag while loading a screen with several rows
    @State private var showIcon = false
    @State private var subtitle = ""
    @State private var title = ""
    @State private var icon: UIImage?
    private let entity: HAAppEntity?
    private let optionalTitle: String?
    private let accessoryImageSystemSymbol: SFSymbol?
    private let isSelected: Bool

    private let iconSize: CGSize = .init(width: 24, height: 24)

    init(
        entity: HAAppEntity? = nil,
        optionalTitle: String? = nil,
        accessoryImageSystemSymbol: SFSymbol? = nil,
        isSelected: Bool = false
    ) {
        self.entity = entity
        self.optionalTitle = optionalTitle
        self.accessoryImageSystemSymbol = accessoryImageSystemSymbol
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            HStack {
                if showIcon, let icon {
                    Image(uiImage: icon)
                }
            }
            .frame(width: iconSize.width, height: iconSize.height)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            if isSelected {
                Image(systemSymbol: .checkmark)
                    .foregroundStyle(.haPrimary)
            } else if let accessoryImageSystemSymbol {
                Image(systemSymbol: accessoryImageSystemSymbol)
                    .foregroundStyle(.white, .green)
                    .font(.title3)
            }
        }
        .animation(.easeInOut, value: showIcon)
        .onAppear {
            title = optionalTitle ?? entity?.registryTitle ?? entity?.name ?? ""
            subtitle = (entity?.contextualSubtitle).orEmpty
            let fallbackIcon = Domain(entityId: (entity?.entityId).orEmpty)?.icon(deviceClass: entity?.rawDeviceClass)
            if let entity {
                icon = MaterialDesignIcons(
                    serversideValueNamed: entity.icon.orEmpty,
                    fallback: fallbackIcon ?? .dotsGridIcon
                ).image(
                    ofSize: .init(width: iconSize.width, height: iconSize.height),
                    color: UIColor(Color.haPrimary)
                )
            }
            showIcon = true
        }
        .onDisappear {
            showIcon = false
        }
    }
}

#Preview {
    EntityRowView(optionalTitle: "Example Entity")
}
