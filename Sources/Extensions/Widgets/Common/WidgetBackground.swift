import Foundation
import SwiftUI

extension View {
    func widgetBackground(_ backgroundView: some ShapeStyle) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(backgroundView, for: .widget)
        } else {
            return background(backgroundView)
        }
    }
}
