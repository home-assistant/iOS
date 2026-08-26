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
        self.items = items
        self.isConfigured = isConfigured
        self.family = family
        self.strings = strings
        self.logo = logo
        self.refreshControl = refreshControl
        self.addControl = addControl
        self.completeControl = completeControl
        self.itemContent = itemContent
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
            Spacer(minLength: 0)
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
                    .padding(DesignSystem.Spaces.one)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .clipShape(.circle)
                Spacer()
            } else {
                Text(title)
                    .font(DesignSystem.Font.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: DesignSystem.Spaces.half) {
                refreshControl(AnyView(
                    Image(systemSymbol: .arrowClockwiseCircle)
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Font.title)
                ))
                addControl(AnyView(
                    Image(systemSymbol: .plusCircleFill)
                        .foregroundStyle(.haPrimary)
                        .font(DesignSystem.Font.title)
                ))
            }
        }
        .padding(.bottom, DesignSystem.Spaces.half)
    }

    private var itemsListView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            if items.isEmpty {
                Text(verbatim: strings.allDone)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            } else {
                ForEach(items) { item in
                    row(for: item)
                }
            }
        }
    }

    private func row(for item: WidgetTodoItemModel) -> some View {
        HStack(alignment: .top) {
            completeControl(item, AnyView(
                Image(systemSymbol: .circle)
                    .font(DesignSystem.Font.title3)
                    .foregroundStyle(.haPrimary)
                    .padding(.top, item.dueText != nil ? DesignSystem.Spaces.micro : 0)
            ))
            itemContent(item, AnyView(
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                    Text(item.summary)
                        .font(DesignSystem.Font.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let dueText = item.dueText {
                        HStack(spacing: DesignSystem.Spaces.half) {
                            Image(uiImage: MaterialDesignIcons.clockTimeTwoIcon.image(
                                ofSize: .init(width: 12, height: 12),
                                color: item.isOverdue ? UIColor.orange : UIColor.secondaryLabel
                            ))
                            Text(dueText)
                                .font(DesignSystem.Font.caption2)
                                .foregroundStyle(item.isOverdue ? Color.orange : .secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            ))
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
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
#endif
