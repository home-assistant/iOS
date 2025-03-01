import SwiftUICore
import UIKit

import SnapshotTesting

func makeDefaultStrategies<Value>(
    layout: SwiftUISnapshotLayout = SwiftUISnapshotLayout.device(config: .iPhone13(.portrait))
) -> [Snapshotting<Value, UIImage>] where Value: View {
    [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark]
        .map { style in
            Snapshotting<Value, UIImage>.image(
                layout: layout,
                traits: .init(userInterfaceStyle: style)
            )
        }
}
