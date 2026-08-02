import SFSafeSymbols
import Shared
import SwiftUI

/// The single grouped "Areas" entry on the home screen, shown when there are too many areas (or
/// multiple servers) to list them inline. Tapping pushes the destination the view model resolved:
/// the server picker, or straight to the only server's area list. Renders as an icon-only tile in
/// the grid layout, matching `WatchFolderRow`.
struct WatchAreasGroupRow: View {
    let destination: WatchHomeNavigation
    var layout: WatchLayout = .list
    @Environment(\.watchNavigate) private var navigate

    var body: some View {
        Button {
            navigate(destination)
        } label: {
            label
        }
        .modify { view in
            if layout == .grid {
                view.watchHomeItemGridStyle(tint: nil)
            } else {
                view
                    .frame(maxWidth: .infinity)
                    .watchHomeItemRowStyle(tint: nil)
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if layout == .grid {
            Image(uiImage: MaterialDesignIcons.textureBoxIcon.image(
                ofSize: .init(width: 28, height: 28),
                color: .white
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(L10n.Watch.Home.Areas.title))
        } else {
            WatchHomeItemLabel(
                name: L10n.Watch.Home.Areas.title,
                textColor: .white,
                icon: {
                    VStack {
                        Image(uiImage: MaterialDesignIcons.textureBoxIcon.image(
                            ofSize: .init(width: 24, height: 24),
                            color: .white
                        ))
                        .padding()
                    }
                    .watchRowIconContainer(color: .white)
                },
                accessory: {
                    Image(systemSymbol: .chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            )
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    return List {
        WatchAreasGroupRow(destination: .areasList(serverId: "1"))
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 60), spacing: DesignSystem.Spaces.one)],
            spacing: DesignSystem.Spaces.one
        ) {
            WatchAreasGroupRow(destination: .areasList(serverId: "1"), layout: .grid)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}
