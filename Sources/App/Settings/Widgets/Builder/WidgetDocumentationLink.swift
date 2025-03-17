import Shared
import SwiftUI

struct WidgetDocumentationLink: View {
    var body: some View {
        Link(destination: ExternalLink.customWidgetsDocumentation) {
            HStack {
                Text(verbatim: L10n.About.Documentation.title)
                Spacer()
                Image(systemSymbol: .arrowUpRightSquare)
            }
        }
    }
}

#Preview {
    WidgetDocumentationLink()
}
