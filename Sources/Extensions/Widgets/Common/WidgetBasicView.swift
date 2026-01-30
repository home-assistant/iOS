import AppIntents
import Shared
import SwiftUI
import WidgetKit

enum WidgetType: String {
    case button
    case sensor
    case custom
}

struct WidgetBasicView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let type: WidgetType
    let rows: [[WidgetBasicViewModel]]
    let sizeStyle: WidgetBasicSizeStyle

    private let opacityWhenDisabled: CGFloat = 0.3
    /// Maximum tile height used for compact layouts in non-small widget families.
    /// This value was measured to keep a single row tile (icon + title + subtitle)
    /// visually balanced within the widget's vertical constraints, accounting for
    /// default padding and text styles from the design system. If typography or
    /// vertical paddings change in `DesignSystem`, this value should be revisited.
    private let maxTileHeightWhenCompact: CGFloat = 68

    var body: some View {
        let spacing = sizeStyle == .compressed ? .zero : DesignSystem.Spaces.one
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: spacing) {
                    ForEach(column) { model in
                        itemContent(model: model)
                            .frame(maxWidth: .infinity)
                    }
                    // Constraint item to single column
                    if column.count == 1, widgetFamily != .systemSmall, sizeStyle == .compact {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding([.single, .compressed].contains(sizeStyle) ? .zero : DesignSystem.Spaces.one)
    }

    private func itemContent(model: WidgetBasicViewModel) -> some View {
        Group {
            if #available(iOS 17, *) {
                if model.showConfirmation {
                    confirmationContent(model: model)
                } else if type == .custom {
                    // For custom widgets, use cardInteractionType for card wrapper (icon handles its own interaction)
                    customWidgetContent(model: model)
                } else if case .widgetURL = model.interactionType {
                    if model.requiresConfirmation {
                        linkThatRequiresConfirmation(model: model)
                    } else {
                        legacyLinkContent(model: model)
                    }
                } else if let intent = intent(for: model, isConfirmationDone: false) {
                    Button(intent: intent) {
                        tintedWrapperView(model: model, sizeStyle: sizeStyle)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Unknown widget configuration (2)")
                }
            } else {
                legacyLinkContent(model: model)
            }
        }
        .frame(maxHeight: (sizeStyle == .compact && widgetFamily != .systemSmall) ? maxTileHeightWhenCompact : nil)
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func customWidgetContent(model: WidgetBasicViewModel) -> some View {
        // When confirmation is required, both icon and card trigger the confirmation dialog.
        // The actual icon/card interaction is executed only after confirmation is granted.
        if model.requiresConfirmation {
            // Use a button that triggers confirmation state for the card area
            Button(intent: {
                let intent = UpdateWidgetItemConfirmationStateAppIntent()
                intent.serverUniqueId = model.id
                intent.widgetId = model.widgetId
                return intent
            }()) {
                tintedWrapperView(model: model, sizeStyle: sizeStyle)
            }
            .buttonStyle(.plain)
        } else {
            // Card interaction type wraps the tile (icon has its own separate interaction)
            switch model.cardInteractionType {
            case let .widgetURL(url):
                Link(destination: url.withWidgetAuthenticity()) {
                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                }
            case let .appIntent(widgetIntentType):
                if let cardIntent = intentFor(
                    interactionType: .appIntent(widgetIntentType),
                    model: model,
                    isConfirmationDone: false
                ) {
                    Button(intent: cardIntent) {
                        tintedWrapperView(model: model, sizeStyle: sizeStyle)
                    }
                    .buttonStyle(.plain)
                } else {
                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                }
            case .noAction:
                tintedWrapperView(model: model, sizeStyle: sizeStyle)
            }
        }
    }

    @available(iOS 16.0, *)
    private func tintedWrapperView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
        Group {
            switch type {
            case .button, .custom:
                return AnyView(WidgetBasicViewTintedWrapper(
                    model: model,
                    sizeStyle: sizeStyle,
                    viewType: WidgetBasicButtonView.self
                ))
            case .sensor:
                return AnyView(WidgetBasicViewTintedWrapper(
                    model: model,
                    sizeStyle: sizeStyle,
                    viewType: WidgetBasicSensorView.self
                ))
            }
        }
        .opacity(model.disabled ? opacityWhenDisabled : 1)
    }

    private func normalView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
        Group {
            switch type {
            case .button, .custom:
                return AnyView(WidgetBasicButtonView(
                    model: model,
                    sizeStyle: sizeStyle,
                    tinted: false
                ))
            case .sensor:
                return AnyView(WidgetBasicSensorView(
                    model: model,
                    sizeStyle: sizeStyle,
                    tinted: false
                ))
            }
        }
        .opacity(model.disabled ? opacityWhenDisabled : 1)
    }

    @available(iOS 17.0, *)
    private func intent(for model: WidgetBasicViewModel, isConfirmationDone: Bool = true) -> (any AppIntent)? {
        intentFor(interactionType: model.interactionType, model: model, isConfirmationDone: isConfirmationDone)
    }

    @available(iOS 17.0, *)
    private func intentFor(
        interactionType: WidgetInteractionType,
        model: WidgetBasicViewModel,
        isConfirmationDone: Bool = true
    ) -> (any AppIntent)? {
        // Delegate to the shared factory, checking confirmation when not done
        WidgetInteractionIntentFactory.intent(
            for: interactionType,
            model: model,
            checkConfirmation: !isConfirmationDone
        )
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    // This view represents the confirmation for for widgets that require confirmation before running
    private func confirmationContent(model: WidgetBasicViewModel) -> some View {
        let confirmationIntent = intent(
            for: model,
            isConfirmationDone: true
        )
        let confirmationURL: URL? = {
            if case let .widgetURL(url) = model.interactionType {
                return url
            } else {
                return nil
            }
        }()
        confirmationForm(
            model: model,
            confirmationIntent: confirmationIntent,
            confirmationURL: confirmationURL,
            cancellationIntent: ResetAllCustomWidgetConfirmationAppIntent()
        )
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    // This view represents the link that requires confirmation before running
    // It triggers an intent to display the confirmation form
    private func linkThatRequiresConfirmation(model: WidgetBasicViewModel) -> some View {
        Button(intent: {
            let intent = UpdateWidgetItemConfirmationStateAppIntent()
            intent.serverUniqueId = model.id
            intent.widgetId = model.widgetId
            return intent
        }()) {
            if #available(iOS 18.0, *) {
                tintedWrapperView(model: model, sizeStyle: sizeStyle)
            } else {
                normalView(model: model, sizeStyle: sizeStyle)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    // This is the only widget we can present prior to iOS 17, because it doesn't support AppIntents
    private func legacyLinkContent(model: WidgetBasicViewModel) -> some View {
        if case let .widgetURL(url) = model.interactionType {
            Link(destination: url.withWidgetAuthenticity()) {
                if #available(iOS 18.0, *) {
                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                } else {
                    normalView(model: model, sizeStyle: sizeStyle)
                }
            }
        } else {
            Text("Unknown widget configuration")
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func confirmationForm(
        model: WidgetBasicViewModel,
        confirmationIntent: (any AppIntent)? = nil,
        confirmationURL: URL? = nil,
        cancellationIntent: any AppIntent
    ) -> some View {
        let cancelImage = Image(systemSymbol: .xmark)
        let confirmImage: some View = {
            let checkmarkImage = Image(systemSymbol: .checkmark)
            if confirmationIntent != nil {
                return AnyView(
                    checkmarkImage
                        .frame(maxWidth: .infinity)
                )
            } else {
                return AnyView(
                    checkmarkImage
                        .foregroundStyle(Color.haPrimary)
                        .frame(maxWidth: .infinity)
                        // Mimic default widget button style
                        .frame(height: 30)
                        .background(sizeStyle == .compressed ? nil : Color.haPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.twoAndHalf))
                )
            }
        }()
        let confirmationColor = Color.haPrimary
        if sizeStyle == .compressed {
            compressedConfirmationForm(
                model: model,
                confirmationIntent: confirmationIntent,
                confirmationURL: confirmationURL,
                cancellationIntent: cancellationIntent,
                confirmImage: confirmImage,
                cancelImage: cancelImage,
                confirmationColor: confirmationColor
            )
        } else if sizeStyle == .compact {
            condensedConfirmationForm(
                model: model,
                confirmationIntent: confirmationIntent,
                confirmationURL: confirmationURL,
                cancellationIntent: cancellationIntent,
                confirmImage: confirmImage,
                cancelImage: cancelImage,
                confirmationColor: confirmationColor
            )
        } else {
            defaultConfirmationForm(
                model: model,
                confirmationIntent: confirmationIntent,
                confirmationURL: confirmationURL,
                cancellationIntent: cancellationIntent,
                confirmImage: confirmImage,
                cancelImage: cancelImage,
                confirmationColor: confirmationColor
            )
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func defaultConfirmationForm(
        model: WidgetBasicViewModel,
        confirmationIntent: (any AppIntent)?,
        confirmationURL: URL?,
        cancellationIntent: any AppIntent,
        confirmImage: some View,
        cancelImage: some View,
        confirmationColor: Color
    ) -> some View {
        VStack {
            Text(verbatim: L10n.Alert.Confirmation.Generic.title)
                .font(.footnote.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            HStack {
                Button(intent: cancellationIntent) {
                    cancelImage
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
                Spacer()
                confirmationLinkOrButton(content: AnyView(
                    confirmImage
                        .frame(maxWidth: .infinity)
                ), confirmationIntent: confirmationIntent, confirmationURL: confirmationURL)
                    .tint(confirmationColor)
            }
        }
        .padding()
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func condensedConfirmationForm(
        model: WidgetBasicViewModel,
        confirmationIntent: (any AppIntent)?,
        confirmationURL: URL?,
        cancellationIntent: any AppIntent,
        confirmImage: some View,
        cancelImage: some View,
        confirmationColor: Color
    ) -> some View {
        VStack(spacing: .zero) {
            Text(verbatim: L10n.Alert.Confirmation.Generic.title)
                .font(.footnote.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], DesignSystem.Spaces.one)
            Spacer()
            HStack {
                Button(intent: cancellationIntent) {
                    cancelImage
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
                confirmationLinkOrButton(content: AnyView(
                    confirmImage
                        .frame(maxWidth: .infinity)
                ), confirmationIntent: confirmationIntent, confirmationURL: confirmationURL)
                    .tint(confirmationColor)
            }
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func compressedConfirmationForm(
        model: WidgetBasicViewModel,
        confirmationIntent: (any AppIntent)?,
        confirmationURL: URL?,
        cancellationIntent: any AppIntent,
        confirmImage: some View,
        cancelImage: some View,
        confirmationColor: Color
    ) -> some View {
        HStack(spacing: .zero) {
            Button(intent: cancellationIntent) {
                cancelImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.red)
                    .padding(DesignSystem.Spaces.half)
                    .background(.red.opacity(0.2))
            }
            .buttonStyle(.plain)
            confirmationLinkOrButton(content: AnyView(
                confirmImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(confirmationColor)
                    .padding(DesignSystem.Spaces.half)
                    .background(confirmationColor.opacity(0.2))
            ), confirmationIntent: confirmationIntent, confirmationURL: confirmationURL)
                .buttonStyle(.plain)
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func confirmationLinkOrButton(
        content: some View,
        confirmationIntent: (any AppIntent)? = nil,
        confirmationURL: URL? = nil
    ) -> some View {
        if let confirmationURL {
            Link(destination: confirmationURL) {
                content
            }
        } else if let confirmationIntent {
            Button(intent: confirmationIntent) {
                content
            }
        } else {
            EmptyView()
        }
    }
}

#Preview {
    WidgetBasicView(
        type: .button,
        rows: [[
            .init(
                id: "1",
                title: "Title",
                subtitle: "Subtitle",
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon,
                disabled: true
            ),
            .init(
                id: "2",
                title: "Title",
                subtitle: "Subtitle",
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon,
                disabled: true
            ),
            .init(
                id: "3",
                title: "Title",
                subtitle: "Subtitle",
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon,
                disabled: true
            ),
        ]],
        sizeStyle: .compressed
    )
}
