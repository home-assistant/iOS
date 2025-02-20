import AppIntents
import Shared
import SwiftUI

enum WidgetType: String {
    case button
    case sensor
    case custom
}

struct WidgetBasicView: View {
    let type: WidgetType
    let rows: [[WidgetBasicViewModel]]
    let sizeStyle: WidgetBasicSizeStyle

    private let opacityWhenDisabled: CGFloat = 0.3

    var body: some View {
        let spacing = sizeStyle == .compressed ? .zero : Spaces.one
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: spacing) {
                    ForEach(column) { model in
                        itemContent(model: model)
                    }
                }
            }
        }
        .padding([.single, .compressed].contains(sizeStyle) ? 0 : Spaces.one)
    }

    @ViewBuilder
    private func itemContent(model: WidgetBasicViewModel) -> some View {
        if #available(iOS 17, *) {
            if model.showConfirmation {
                confirmationContent(model: model)
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
                        .foregroundStyle(Color.asset(Asset.Colors.haPrimary))
                        .frame(maxWidth: .infinity)
                        // Mimic default widget button style
                        .frame(height: 30)
                        .background(sizeStyle == .compressed ? nil : Color.asset(Asset.Colors.haPrimary).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                )
            }
        }()
        let confirmationColor = Color.asset(Asset.Colors.haPrimary)
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
        } else if sizeStyle == .condensed {
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
                .padding([.horizontal, .top], Spaces.one)
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
                    .padding(Spaces.half)
                    .background(.red.opacity(0.2))
            }
            .buttonStyle(.plain)
            confirmationLinkOrButton(content: AnyView(
                confirmImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(confirmationColor)
                    .padding(Spaces.half)
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
        switch model.interactionType {
        case .widgetURL:
            return nil
        case let .appIntent(widgetIntentType):
            // When confirmation is required and this method wasn't called from confirmation button
            if model.requiresConfirmation, !isConfirmationDone {
                let intent = UpdateWidgetItemConfirmationStateAppIntent()
                intent.widgetId = model.widgetId
                intent.serverUniqueId = model.id
                return intent
            }
            switch widgetIntentType {
            case .action:
                let intent = PerformAction()
                intent.action = IntentActionAppEntity(id: model.id, displayString: model.title)
                intent.hapticConfirmation = true
                return intent
            case let .script(id, entityId, serverId, name, showConfirmationNotification):
                let intent = ScriptAppIntent()
                intent.script = .init(
                    id: id,
                    entityId: entityId,
                    serverId: serverId,
                    serverName: "", // not used in this context
                    displayString: name,
                    iconName: "" // not used in this context
                )
                intent.hapticConfirmation = true
                intent.showConfirmationNotification = showConfirmationNotification
                return intent
            case .refresh:
                return ReloadWidgetsAppIntent()
            case let .toggle(entityId, domain, serverId):
                let intent = CustomWidgetToggleAppIntent()
                intent.domain = domain
                intent.entityId = entityId
                intent.serverId = serverId
                intent.widgetShowingStates = model.subtitle != nil
                return intent
            case let .activate(entityId, domain, serverId):
                let intent = CustomWidgetActivateAppIntent()
                intent.domain = domain
                intent.entityId = entityId
                intent.serverId = serverId
                return intent
            case let .press(entityId, domain, serverId):
                let intent = CustomWidgetPressButtonAppIntent()
                intent.domain = domain
                intent.entityId = entityId
                intent.serverId = serverId
                return intent
            }
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
