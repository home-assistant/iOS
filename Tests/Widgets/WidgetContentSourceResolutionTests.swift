@testable import HomeAssistant

import Shared
import Testing

/// The source the gauge and details widgets render for a stored configuration.
///
/// Both widgets shipped template-only, then gained a `source` picker whose default later moved from
/// template to entity. A configuration saved before the picker existed stores no source, so it decodes
/// as the entity default with the user's templates still attached — and must keep rendering them.
struct WidgetContentSourceResolutionTests {
    // MARK: - Shared rule

    @Test func entityWithoutAnEntityButWithTemplatesIsALegacyTemplateWidget() {
        let source = WidgetContentSourceAppEnum.resolved(configured: .entity, hasEntity: false, hasTemplates: true)
        #expect(source == .template)
    }

    @Test func entityWithoutAnEntityAndWithoutTemplatesStaysEntity() {
        let source = WidgetContentSourceAppEnum.resolved(configured: .entity, hasEntity: false, hasTemplates: false)
        #expect(source == .entity)
    }

    /// Picking an entity is the user's decision, even when stale templates linger in the configuration.
    @Test func entityWithAnEntityStaysEntityEvenWithTemplates() {
        let source = WidgetContentSourceAppEnum.resolved(configured: .entity, hasEntity: true, hasTemplates: true)
        #expect(source == .entity)
    }

    @Test func explicitTemplateAndComplicationAreLeftAlone() {
        let template = WidgetContentSourceAppEnum.resolved(configured: .template, hasEntity: true, hasTemplates: false)
        #expect(template == .template)

        let complication = WidgetContentSourceAppEnum.resolved(
            configured: .complication,
            hasEntity: false,
            hasTemplates: true
        )
        #expect(complication == .complication)
    }

    // MARK: - Gauge

    /// A gauge configured before the source picker existed: no source stored, templates filled in.
    @available(iOS 17, *)
    @Test func legacyGaugeConfigurationRendersItsTemplates() {
        let configuration = WidgetGaugeAppIntent()
        configuration.valueTemplate = "{{ state_attr('climate.central_heating', 'current_temperature') / 30 }}"
        configuration.valueLabelTemplate = "{{ state_attr('climate.central_heating', 'current_temperature') }}"
        configuration.labelTemplate = "{{ states('climate.central_heating') }}"

        #expect(configuration.source == .entity)
        #expect(configuration.resolvedSource == .template)
    }

    /// Any one template field is enough to recognize a legacy gauge.
    @available(iOS 17, *)
    @Test func legacyGaugeWithOnlyAMinOrMaxTemplateStillRendersTemplates() {
        let configuration = WidgetGaugeAppIntent()
        configuration.maxTemplate = "100"

        #expect(configuration.resolvedSource == .template)
    }

    @available(iOS 17, *)
    @Test func freshGaugeConfigurationStaysEntity() {
        #expect(WidgetGaugeAppIntent().resolvedSource == .entity)
    }

    @available(iOS 17, *)
    @Test func gaugeWithAPickedEntityRendersTheEntity() {
        let configuration = WidgetGaugeAppIntent()
        configuration.entity = Self.entity
        configuration.valueTemplate = "0.5"

        #expect(configuration.resolvedSource == .entity)
    }

    // MARK: - Details

    @available(iOS 17, *)
    @Test func legacyDetailsConfigurationRendersItsTemplates() {
        let configuration = WidgetDetailsAppIntent()
        configuration.lowerTemplate = "{{ states('sensor.outside_temperature') }}"

        #expect(configuration.source == .entity)
        #expect(configuration.resolvedSource == .template)
    }

    @available(iOS 17, *)
    @Test func freshDetailsConfigurationStaysEntity() {
        #expect(WidgetDetailsAppIntent().resolvedSource == .entity)
    }

    @available(iOS 17, *)
    @Test func detailsWithAPickedEntityRendersTheEntity() {
        let configuration = WidgetDetailsAppIntent()
        configuration.entity = Self.entity
        configuration.upperTemplate = "Outside"

        #expect(configuration.resolvedSource == .entity)
    }

    private static let entity = HAAppEntityAppIntentEntity(
        id: "server-1-climate.central_heating",
        entityId: "climate.central_heating",
        serverId: "server-1",
        serverName: "Home",
        displayString: "Central Heating",
        iconName: "mdi:thermostat"
    )
}
