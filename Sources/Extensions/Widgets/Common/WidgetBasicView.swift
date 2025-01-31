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
        if model.showConfirmation, #available(iOS 17.0, *), let confirmationIntent = intent(
            for: model,
            isConfirmationDone: true
        ) {
            confirmationForm(
                model: model,
                confirmationIntent: confirmationIntent,
                cancellationIntent: ResetAllCustomWidgetConfirmationAppIntent()
            )
        } else if case let .widgetURL(url) = model.interactionType {
            Link(destination: url.withWidgetAuthenticity()) {
                if #available(iOS 18.0, *) {
                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                } else {
                    normalView(model: model, sizeStyle: sizeStyle)
                }
            }
        } else {
            if #available(iOS 17.0, *), let intent = intent(for: model, isConfirmationDone: false) {
                Button(intent: intent) {
                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func confirmationForm(
        model: WidgetBasicViewModel,
        confirmationIntent: any AppIntent,
        cancellationIntent: any AppIntent
    ) -> some View {
        let cancelImage = Image(systemSymbol: .xmark)
        let confirmImage = Image(systemSymbol: .checkmark)
        let confirmationColor = Color.asset(Asset.Colors.haPrimary)
        if sizeStyle == .compressed {
            HStack(spacing: .zero) {
                Button(intent: cancellationIntent) {
                    cancelImage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.red)
                        .padding(Spaces.half)
                        .background(.red.opacity(0.2))
                }
                .buttonStyle(.plain)
                Button(intent: confirmationIntent) {
                    confirmImage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(confirmationColor)
                        .padding(Spaces.half)
                        .background(confirmationColor.opacity(0.2))
                }
                .buttonStyle(.plain)
            }
        } else if sizeStyle == .condensed {
            VStack(spacing: .zero) {
                Text(L10n.Alert.Confirmation.Generic.title)
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .top], Spaces.one)
                Spacer()
                HStack {
                    Group {
                        Button(intent: cancellationIntent) {
                            cancelImage
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.red)
                        Button(intent: confirmationIntent) {
                            confirmImage
                                .frame(maxWidth: .infinity)
                        }
                        .tint(confirmationColor)
                    }
                }
            }
        } else {
            VStack {
                Text(L10n.Alert.Confirmation.Generic.title)
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                HStack {
                    Button(intent: cancellationIntent) {
                        cancelImage
                    }
                    .tint(.red)
                    Spacer()
                    Button(intent: confirmationIntent) {
                        confirmImage
                    }
                    .tint(confirmationColor)
                }
            }
            .padding()
        }
    }

    @available(iOS 16.0, *)
    private func tintedWrapperView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
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

    private func normalView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
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
                icon: .abTestingIcon
            ),
        ]],
        sizeStyle: .compressed
    )
}
