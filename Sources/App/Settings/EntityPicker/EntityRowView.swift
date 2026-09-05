import HADesignSystem
import SFSafeSymbols
import Shared
import SwiftUI

struct EntityRowView: View {
    /// Where the row's content comes from. A long list resolves it for every row up front, so that
    /// scrolling neither reads the database nor writes view state: each state write schedules a
    /// SwiftUI update, and every update makes `List` re-solve the layout of all of its sections.
    private enum Content {
        case resolved(subtitle: String?, icon: MaterialDesignIcons?)
        case resolvedByRow
    }

    // Only the rows that resolve their own content need state, and only they pay for it.
    @State private var showIcon = false
    @State private var rowSubtitle = ""
    @State private var rowIcon: MaterialDesignIcons?
    private let entity: HAAppEntity?
    private let optionalTitle: String?
    private let accessoryImageSystemSymbol: SFSymbol?
    private let isSelected: Bool
    private let content: Content

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
        self.content = .resolvedByRow
    }

    init(
        entity: HAAppEntity?,
        subtitle: String?,
        icon: MaterialDesignIcons?,
        accessoryImageSystemSymbol: SFSymbol? = nil,
        isSelected: Bool = false
    ) {
        self.entity = entity
        self.optionalTitle = nil
        self.accessoryImageSystemSymbol = accessoryImageSystemSymbol
        self.isSelected = isSelected
        self.content = .resolved(subtitle: subtitle, icon: icon)
    }

    private var title: String {
        optionalTitle ?? entity?.name ?? ""
    }

    private var subtitle: String {
        switch content {
        case let .resolved(subtitle, _): subtitle.orEmpty
        case .resolvedByRow: rowSubtitle
        }
    }

    private var icon: MaterialDesignIcons? {
        switch content {
        case let .resolved(_, icon): icon
        case .resolvedByRow: showIcon ? rowIcon : nil
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            HStack {
                if let icon {
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
        .modify { view in
            if case .resolvedByRow = content {
                view
                    .animation(.easeInOut, value: showIcon)
                    .onAppear {
                        rowSubtitle = (entity?.contextualSubtitle).orEmpty
                        rowIcon = entity?.materialDesignIcon
                        showIcon = true
                    }
                    .onDisappear {
                        showIcon = false
                    }
            } else {
                view
            }
        }
    }
}

#Preview {
    EntityRowView(optionalTitle: "Example Entity")
}
