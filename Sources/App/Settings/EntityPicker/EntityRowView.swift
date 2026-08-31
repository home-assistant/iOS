import HADesignSystem
import SFSafeSymbols
import Shared
import SwiftUI

struct EntityRowView: View {
    /// Where the context line comes from: resolved by the caller for the whole list, or by the row
    /// itself — which costs a database read per row, so long lists resolve it in bulk instead.
    private enum SubtitleSource {
        case provided(String?)
        case resolvedByRow
    }

    // This avoids lag while loading a screen with several rows
    @State private var showIcon = false
    @State private var resolvedSubtitle = ""
    @State private var title = ""
    @State private var icon: MaterialDesignIcons?
    private let entity: HAAppEntity?
    private let optionalTitle: String?
    private let accessoryImageSystemSymbol: SFSymbol?
    private let isSelected: Bool
    private let subtitleSource: SubtitleSource

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
        self.subtitleSource = .resolvedByRow
    }

    init(
        entity: HAAppEntity?,
        subtitle: String?,
        accessoryImageSystemSymbol: SFSymbol? = nil,
        isSelected: Bool = false
    ) {
        self.entity = entity
        self.optionalTitle = nil
        self.accessoryImageSystemSymbol = accessoryImageSystemSymbol
        self.isSelected = isSelected
        self.subtitleSource = .provided(subtitle)
    }

    private var subtitle: String {
        switch subtitleSource {
        case let .provided(subtitle): subtitle.orEmpty
        case .resolvedByRow: resolvedSubtitle
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            HStack {
                if showIcon, let icon {
                    // The design system's cached glyph, rather than rendering one per row: the row
                    // re-appears constantly while a long list scrolls.
                    MaterialDesignIconsImage(icon: icon, size: iconSize.width)
                        .foregroundStyle(Color.gray)
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
            title = optionalTitle ?? entity?.name ?? ""
            if case .resolvedByRow = subtitleSource {
                resolvedSubtitle = (entity?.contextualSubtitle).orEmpty
            }
            let fallbackIcon = Domain(entityId: (entity?.entityId).orEmpty)?.icon(deviceClass: entity?.rawDeviceClass)
            if let entity {
                // Prefer the entity's own icon override, then the frontend-matching default resolved
                // from the backend `entity_component` map at sync time, then the domain fallback.
                let iconName = entity.icon?.isEmpty == false ? entity.icon : entity.resolvedIcon
                icon = MaterialDesignIcons(
                    serversideValueNamed: iconName.orEmpty,
                    fallback: fallbackIcon ?? .dotsGridIcon
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
