#if !os(watchOS)
import SwiftUI

/// A picture with a row of entity chips across the bottom — a camera view with the doors and lights
/// of the room it shows. The SwiftUI counterpart of the frontend's `hui-picture-glance-card`.
///
/// Built on ``HAPictureCard``'s footer slot rather than redrawing the picture.
public struct HAPictureGlanceCard: View {
    private let image: Image
    private let aspectRatio: CGFloat
    private let title: String?
    private let items: [HAGlanceItem]
    private let onTapItem: ((HAGlanceItem) -> Void)?

    public init(
        image: Image,
        aspectRatio: CGFloat = 16 / 9,
        title: String? = nil,
        items: [HAGlanceItem],
        onTapItem: ((HAGlanceItem) -> Void)? = nil
    ) {
        self.image = image
        self.aspectRatio = aspectRatio
        self.title = title
        self.items = items
        self.onTapItem = onTapItem
    }

    public var body: some View {
        HAPictureCard(image: image, aspectRatio: aspectRatio, name: title) {
            HStack(spacing: DesignSystem.Spaces.two) {
                ForEach(items) { item in
                    Button {
                        onTapItem?(item)
                    } label: {
                        VStack(spacing: DesignSystem.Spaces.micro) {
                            if let icon = item.icon {
                                MaterialDesignIconsImage(icon: icon, size: 20)
                            }
                            if let state = item.state {
                                Text(state)
                                    .font(.system(size: 12))
                            }
                        }
                        // White on its own scrim: the chips sit over a picture whose colours the
                        // card cannot know.
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(item.name))
                }
            }
            .padding(DesignSystem.Spaces.one)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.4))
        }
    }
}

#Preview {
    HAPictureGlanceCard(
        image: Image(systemSymbol: .photo),
        title: "Front garden",
        items: [
            HAGlanceItem(id: "1", name: "Porch light", icon: .lightbulbOnIcon, state: "On"),
            HAGlanceItem(id: "2", name: "Front door", icon: .doorIcon, state: "Closed"),
            HAGlanceItem(id: "3", name: "Garage", icon: .garageIcon, state: "Closed"),
        ]
    )
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAPictureGlanceCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-picture-glance-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
