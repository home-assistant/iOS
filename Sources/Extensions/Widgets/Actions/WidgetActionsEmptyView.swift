import Foundation
import SwiftUI
import Shared

struct WidgetActionsEmptyView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            Text(verbatim: L10n.Widgets.Actions.notConfigured)
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
        }
    }
}

#if DEBUG
import WidgetKit

struct WidgetActionsEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetActionsEmptyView()
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .environment(\.colorScheme, .dark)

        WidgetActionsEmptyView()
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .environment(\.colorScheme, .light)

        WidgetActionsEmptyView()
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .environment(\.colorScheme, .dark)

        WidgetActionsEmptyView()
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .environment(\.colorScheme, .light)

        WidgetActionsEmptyView()
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .environment(\.colorScheme, .dark)

        WidgetActionsEmptyView()
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .environment(\.colorScheme, .light)
    }
}
#endif
