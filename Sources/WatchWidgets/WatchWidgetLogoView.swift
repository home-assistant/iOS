import SwiftUI

struct WatchWidgetLogoView: View {
    var padding = WatchWidgetConstants.Layout.logoPadding

    var body: some View {
        Image(WatchWidgetConstants.logoAssetName)
            .resizable()
            .scaledToFit()
            .padding(padding)
    }
}
