import AppIntents
import Foundation
import Shared
import SwiftUI

protocol WidgetBasicViewProtocol: View {
    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle, tinted: Bool)
    var model: WidgetBasicViewModel { get }
    var sizeStyle: WidgetBasicSizeStyle { get }
    var tinted: Bool { get }
}
