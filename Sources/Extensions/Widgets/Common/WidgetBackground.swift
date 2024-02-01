import Foundation
import SwiftUI

extension View {
    func widgetBackground(_ backgroundView: AnyView?) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(for: .widget) {
                if let backgroundView {
                    backgroundView
                } else {
                    EmptyView()
                }
            }
        } else {
            return background(backgroundView)
        }
    }
}
