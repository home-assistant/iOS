import SwiftUI
import WidgetKit

extension WidgetConfiguration {
    func haWidgetPushHandlerIfAvailable() -> some WidgetConfiguration {
        if #available(iOS 26.0, *) {
            return self.pushHandler(HAWidgetPushHandler.self)
        } else {
            return self
        }
    }
}
