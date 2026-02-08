import HAKit
import Shared
import SwiftUI

/// Pure UI component for displaying an entity tile
/// This view is designed to be reusable across different contexts in the app
///
/// ## Usage Example
/// ```swift
/// // Simple usage with static data
/// EntityTileView(
///     entityName: "Living Room Light",
///     entityState: "On",
///     icon: .lightbulbIcon,
///     iconColor: .yellow,
///     isUnavailable: false,
///     onIconTap: {
///         // Handle icon tap action
///     },
///     onTileTap: {
///         // Handle tile tap action
///     }
/// )
///
/// // Usage in a custom view
/// struct CustomEntityList: View {
///     let entities: [MyCustomEntity]
///
///     var body: some View {
///         ForEach(entities) { entity in
///             EntityTileView(
///                 entityName: entity.name,
///                 entityState: entity.status,
///                 icon: entity.icon,
///                 iconColor: entity.color,
///                 onIconTap: { performAction(on: entity) }
///             )
///         }
///     }
/// }
/// ```
///
/// For Home Assistant entity integration, use `HomeEntityTileView` instead,
/// which handles all the business logic like device class lookup, icon color
/// computation, and AppIntents integration.
@available(iOS 26.0, *)
struct EntityTileView: View {
    enum Constants {
        static let tileHeight: CGFloat = 65
        static let cornerRadius: CGFloat = 16
        static let iconSize: CGFloat = 38
        static let iconFontSize: CGFloat = 20
        static let iconOpacity: CGFloat = 0.3
        static let borderLineWidth: CGFloat = 1
        static let textVStackSpacing: CGFloat = 2
    }

    // MARK: - Display Data

    let entityName: String
    let entityState: String
    let icon: MaterialDesignIcons
    let iconColor: Color
    let isUnavailable: Bool
    let onIconTap: (() -> Void)?
    let onTileTap: (() -> Void)?

    // MARK: - State

    @State private var triggerHaptic = 0

    // MARK: - Initializer

    init(
        entityName: String,
        entityState: String,
        icon: MaterialDesignIcons,
        iconColor: Color,
        isUnavailable: Bool = false,
        onIconTap: (() -> Void)? = nil,
        onTileTap: (() -> Void)? = nil
    ) {
        self.entityName = entityName
        self.entityState = entityState
        self.icon = icon
        self.iconColor = iconColor
        self.isUnavailable = isUnavailable
        self.onIconTap = onIconTap
        self.onTileTap = onTileTap
    }

    // MARK: - Body

    var body: some View {
        tileContent
            .frame(height: Constants.tileHeight)
            .frame(maxWidth: .infinity)
            .background(.tileBackground)
            .contentShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(
                        isUnavailable ? .gray : .tileBorder,
                        style: isUnavailable ?
                            StrokeStyle(lineWidth: Constants.borderLineWidth, dash: [5, 3]) :
                            StrokeStyle(lineWidth: Constants.borderLineWidth)
                    )
            )
            .opacity(isUnavailable ? 0.5 : 1.0)
            .onTapGesture {
                onTileTap?()
            }
    }

    // MARK: - View Components

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            contentRow
                .padding([.leading, .trailing], DesignSystem.Spaces.oneAndHalf)
        }
    }

    private var contentRow: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
            iconView
            entityInfoStack
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var entityInfoStack: some View {
        VStack(alignment: .leading, spacing: Constants.textVStackSpacing) {
            entityNameText
            entityStateText
        }
    }

    private var entityNameText: some View {
        Text(entityName)
            .font(.footnote)
            .fontWeight(.semibold)
        #if os(iOS)
            .foregroundColor(Color(uiColor: .label))
        #else
            .foregroundColor(.primary)
        #endif
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    private var entityStateText: some View {
        Text(entityState)
            .font(.caption)
        #if os(iOS)
            .foregroundColor(Color(uiColor: .secondaryLabel))
        #else
            .foregroundColor(.secondary)
        #endif
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var iconView: some View {
        Button {
            onIconTap?()
            triggerHaptic += 1
        } label: {
            VStack {
                Text(verbatim: icon.unicode)
                    .font(.custom(MaterialDesignIcons.familyName, size: Constants.iconFontSize))
                    .foregroundColor(iconColor)
                    .fixedSize(horizontal: false, vertical: false)
            }
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(iconColor.opacity(Constants.iconOpacity))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: triggerHaptic)
    }
}
