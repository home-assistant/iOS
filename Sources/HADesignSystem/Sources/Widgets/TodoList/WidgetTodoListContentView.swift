#if !os(watchOS)
import Foundation
import HAIconic
import SFSafeSymbols
import SwiftUI
import UIKit
import WidgetKit

/// The to-do widget: the list's name, a reload and an add control, then the open items with their
/// due dates.
///
/// The controls are handed back to the caller to wrap — completing an item is an App Intent and
/// adding one is a deep link, neither of which the design system knows how to build.
@available(iOS 17, *)
public struct WidgetTodoListContentView: View {
    /// Wraps a rendered control in whatever runs it.
    public typealias ControlContent = (AnyView) -> AnyView
    /// Wraps a rendered piece of a row in whatever runs it.
    public typealias ItemContent = (WidgetTodoItemModel, AnyView) -> AnyView

    private let title: String
    private let items: [WidgetTodoItemModel]
    /// Whether a list has been picked at all. Without one there is nothing to draw but the prompt.
    private let isConfigured: Bool
    private let family: WidgetFamily
    private let strings: WidgetTodoListStrings
    private let logo: Image?
    private let refreshControl: ControlContent
    private let addControl: ControlContent
    private let completeControl: ItemContent
    private let itemContent: ItemContent
    /// How much of each row's text fits, which the small family's width decides.
    private let sizeStyle: WidgetTodoListSizeStyle
    /// The height of a summary's capitals at the reader's text size: SF's 0.705 em of the body
    /// style's 17pt, scaled with Dynamic Type. The checkbox is centred on it.
    @ScaledMetric(relativeTo: .body) private var summaryCapHeight: CGFloat = 12

    public init(
        title: String,
        items: [WidgetTodoItemModel],
        isConfigured: Bool,
        family: WidgetFamily,
        strings: WidgetTodoListStrings,
        logo: Image? = nil,
        refreshControl: @escaping ControlContent = { $0 },
        addControl: @escaping ControlContent = { $0 },
        completeControl: @escaping ItemContent = { _, control in control },
        itemContent: @escaping ItemContent = { _, content in content }
    ) {
        self.title = title
        // Clipped here as well as by the timeline, so no caller can hand the family more rows than
        // it has room to draw.
        self.items = Array(items.prefix(WidgetTileLayout.todoListSize(for: family)))
        self.isConfigured = isConfigured
        self.family = family
        self.strings = strings
        self.logo = logo
        self.refreshControl = refreshControl
        self.addControl = addControl
        self.completeControl = completeControl
        self.itemContent = itemContent
        self.sizeStyle = WidgetTodoListSizeStyle(family: family)
    }

    public var body: some View {
        if isConfigured {
            contentView
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: .checklistChecked)
                .font(.system(size: 32))
                .foregroundStyle(.haPrimary)
            Text(verbatim: strings.title)
                .font(DesignSystem.Font.callout.bold())
            Text(verbatim: strings.selectList)
                .font(DesignSystem.Font.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: .zero) {
            headerView
            itemsListView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            if family != .systemSmall, let logo {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(DesignSystem.Spaces.half)
            }
        }
    }

    private var headerView: some View {
        HStack {
            if family == .systemSmall {
                Text(verbatim: title.first.map(String.init) ?? "")
                    .font(sizeStyle.initialFont)
                    .padding(DesignSystem.Spaces.one)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .clipShape(.circle)
                Spacer()
            } else {
                Text(verbatim: title)
                    .font(sizeStyle.titleFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: DesignSystem.Spaces.half) {
                refreshControl(AnyView(
                    Image(systemSymbol: .arrowClockwiseCircle)
                        .foregroundStyle(.secondary)
                        .font(sizeStyle.controlFont)
                ))
                addControl(AnyView(
                    Image(systemSymbol: .plusCircleFill)
                        .foregroundStyle(.haPrimary)
                        .font(sizeStyle.controlFont)
                ))
            }
        }
        .padding(.bottom, DesignSystem.Spaces.one)
    }

    private var itemsListView: some View {
        VStack(alignment: .leading, spacing: sizeStyle.rowSpacing) {
            if items.isEmpty {
                Text(verbatim: strings.allDone)
                    .font(sizeStyle.summaryFont)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            } else if sizeStyle.dropsRowsToFit {
                // The most rows that fit whole: every row, then one fewer, and so on.
                ViewThatFits(in: .vertical) {
                    ForEach(Array(stride(from: items.count, through: 1, by: -1)), id: \.self) { count in
                        rows(Array(items.prefix(count)))
                    }
                }
            } else {
                rows(items)
            }
        }
    }

    /// Halfway up the capitals of a text's first line, which is where a line of text looks centred.
    private static let capCenter = VerticalAlignment(CapCenter.self)

    private enum CapCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    /// SF's capitals are 0.705 em tall on a 1.294 em line. Taking that share of the summary's line as
    /// drawn keeps the guide right at every Dynamic Type size, and for a summary a minimum scale factor
    /// shrank — which the checkbox, drawn at full size, never is.
    private static func capCenter(in dimensions: ViewDimensions) -> CGFloat {
        let laterLines = dimensions[.lastTextBaseline] - dimensions[.firstTextBaseline]
        let lineHeight = dimensions.height - laterLines
        return dimensions[.firstTextBaseline] - lineHeight * (0.705 / 1.294) / 2
    }

    private func rows(_ items: [WidgetTodoItemModel]) -> some View {
        VStack(alignment: .leading, spacing: sizeStyle.rowSpacing) {
            ForEach(items) { item in
                row(for: item)
            }
        }
    }

    private func row(for item: WidgetTodoItemModel) -> some View {
        // The circle is a symbol set in the summary's own font, and the two meet halfway up their
        // capitals: level with a one-line summary, with the first line of one that wraps, and with
        // one shrunk to fit, which a shared baseline would leave sitting low.
        HStack(alignment: Self.capCenter) {
            completeControl(item, AnyView(
                Text(Image(systemSymbol: .circle))
                    .font(sizeStyle.summaryFont)
                    .imageScale(.large)
                    .foregroundStyle(.haPrimary)
                    // The symbol's line is taller than the text's, so its capitals are found from
                    // its baseline rather than from its height.
                    .alignmentGuide(Self.capCenter) { $0[.firstTextBaseline] - summaryCapHeight / 2 }
            ))
            itemContent(item, AnyView(
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                    Text(verbatim: item.summary)
                        .font(sizeStyle.summaryFont)
                        .lineLimit(sizeStyle.summaryLineLimit(hasDueText: item.dueText != nil))
                        .minimumScaleFactor(sizeStyle.minimumScaleFactor)
                        .truncationMode(.tail)
                        .alignmentGuide(Self.capCenter, computeValue: Self.capCenter(in:))
                    if let dueText = item.dueText {
                        dueLine(text: dueText, isOverdue: item.isOverdue)
                    } else if sizeStyle.reservesDueLine {
                        // Holds the date's line open, so this row is as tall as one with a date.
                        dueLine(text: " ", isOverdue: false)
                            .hidden()
                            .accessibilityHidden(true)
                    }
                }
            ))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func dueLine(text: String, isOverdue: Bool) -> some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            Image(uiImage: MaterialDesignIcons.clockTimeTwoIcon.image(
                ofSize: .init(width: sizeStyle.dueIconSize, height: sizeStyle.dueIconSize),
                color: isOverdue ? UIColor.orange : UIColor.secondaryLabel
            ))
            Text(verbatim: text)
                .font(sizeStyle.dueFont)
                .foregroundStyle(isOverdue ? Color.orange : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(sizeStyle.minimumScaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@available(iOS 17, *)
#Preview {
    WidgetTodoListContentView(
        title: "Groceries",
        items: [
            .init(id: "1", summary: "Coffee beans"),
            .init(id: "2", summary: "Book a table", dueText: "Tomorrow"),
            .init(id: "3", summary: "Water the plants", dueText: "Yesterday", isOverdue: true),
        ],
        isConfigured: true,
        family: .systemMedium,
        strings: .preview
    )
    .padding()
    .frame(width: 338, height: 158)
}

@available(iOS 17, *)
#Preview("Small") {
    WidgetTodoListContentView(
        title: "Groceries",
        items: [
            .init(id: "1", summary: "Coffee beans"),
            .init(id: "2", summary: "Book a table", dueText: "Tomorrow"),
            .init(id: "3", summary: "Water the plants", dueText: "Yesterday", isOverdue: true),
        ],
        isConfigured: true,
        family: .systemSmall,
        strings: .preview
    )
    .padding()
    .frame(width: 170, height: 170)
}
#endif
