#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI
import UIKit
import WidgetKit

/// The small Assist widget: the Assist glyph over the action and the pipeline it will open.
///
/// One tap target for the whole tile, so there is nothing to lay out beyond centring the mark and
/// the two lines under it.
public struct WidgetAssistSingleView: View {
    private let title: String
    private let subtitle: String
    private let tinted: Bool

    public init(title: String, subtitle: String, tinted: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.tinted = tinted
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Spacer()
            Group {
                Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                    ofSize: .init(width: 56, height: 56),
                    color: UIColor.haPrimary
                ))
                .foregroundStyle(.ultraThickMaterial)
                VStack(spacing: .zero) {
                    Group {
                        Text(verbatim: title)
                            .font(.footnote.bold())
                            .foregroundColor(Color(uiColor: .label))
                        Text(verbatim: subtitle)
                            .font(.footnote.weight(.light))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .modify { view in
                if #available(iOS 18, *) {
                    view.widgetAccentable()
                } else {
                    view
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.two)
        .background(tinted ? Color.clear : Color(uiColor: .systemBackground))
    }
}

#Preview {
    WidgetAssistSingleView(title: "Assist", subtitle: "Home Assistant")
        .frame(width: 160, height: 160)
}
#endif
