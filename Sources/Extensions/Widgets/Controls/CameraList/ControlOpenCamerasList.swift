import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit
import SFSafeSymbols

@available(iOS 18, *)
struct ControlOpenCamerasList: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: WidgetsKind.controlOpenCamerasList.rawValue
        ) {
            ControlWidgetButton(action: OpenCameraListAppIntent()) {
                Label(L10n.CameraList.title, systemImage: SFSymbol.videoFill.rawValue)
            }
        }
        .displayName(.init(stringLiteral: L10n.CameraList.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenCamerasList.description))
    }
}
