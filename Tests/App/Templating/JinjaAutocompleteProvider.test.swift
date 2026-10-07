import Foundation
@testable import HomeAssistant
import Testing

struct JinjaAutocompleteProviderTests {
    private let provider = JinjaAutocompleteProvider(entityIds: [
        "light.kitchen",
        "sensor.bruno_battery_level",
        "sensor.solar_power",
    ])

    // MARK: - Suggestions (footer pills)

    @Test func openQuoteFiltersByTypedPrefix() {
        let text = "{{ states('sen"
        let suggestions = provider.entitySuggestions(text: text, cursorLocation: (text as NSString).length)
        #expect(suggestions.map(\.label) == ["sensor.bruno_battery_level", "sensor.solar_power"])
        // The bare id replaces the typed prefix.
        #expect(suggestions.first?.insertion == "sensor.bruno_battery_level")
        #expect(suggestions.first?.replacingCount == 3)
    }

    @Test func noSuggestionsUntilTypingInsideAQuote() {
        // Empty on open / in literal text / in an expression without an open quote / after a
        // closed quote — pills only appear while an entity id is being typed.
        #expect(provider.entitySuggestions(text: "", cursorLocation: 0).isEmpty)
        #expect(provider.entitySuggestions(text: "literal", cursorLocation: 7).isEmpty)
        #expect(provider.entitySuggestions(text: "{{ ", cursorLocation: 3).isEmpty)
        let closed = "{{ states('sensor.solar_power') "
        #expect(provider.entitySuggestions(text: closed, cursorLocation: (closed as NSString).length).isEmpty)
    }

    @Test func freshlyOpenedQuoteOffersAllEntities() {
        let text = "{{ states('"
        let suggestions = provider.entitySuggestions(text: text, cursorLocation: (text as NSString).length)
        #expect(suggestions.count == 3)
        #expect(suggestions.first?.insertion == "light.kitchen")
    }

    @Test func suggestionsAreLimited() {
        let many = JinjaAutocompleteProvider(entityIds: (0 ..< 20).map { "sensor.n\($0)" })
        let text = "{{ states('"
        #expect(many.entitySuggestions(text: text, cursorLocation: (text as NSString).length, limit: 5).count == 5)
    }

    @Test func quotedPrefixMatchesPillFilter() {
        let text = "{{ states('sen"
        #expect(provider.quotedPrefix(text: text, cursorLocation: (text as NSString).length) == "sen")
        #expect(provider.quotedPrefix(text: "{{ ", cursorLocation: 3) == nil)
        #expect(provider.quotedPrefix(text: "literal", cursorLocation: 7) == nil)
    }

    // MARK: - Insertion (pill tap / entity picker)

    @Test func insertionInLiteralTextWrapsInExpression() {
        let insertion = provider.entityInsertion(for: "sensor.solar_power", text: "", cursorLocation: 0)
        #expect(insertion.insertion == "{{ states('sensor.solar_power') }}")
        #expect(insertion.replacingCount == 0)
    }

    @Test func insertionAfterClosedExpressionWrapsInExpression() {
        let text = "{{ states('sensor.x') }} kW "
        let insertion = provider.entityInsertion(
            for: "sensor.solar_power",
            text: text,
            cursorLocation: (text as NSString).length
        )
        #expect(insertion.insertion == "{{ states('sensor.solar_power') }}")
    }

    @Test func insertionInsideExpressionBecomesStatesCall() {
        let text = "{{ "
        let insertion = provider.entityInsertion(
            for: "sensor.solar_power",
            text: text,
            cursorLocation: (text as NSString).length
        )
        #expect(insertion.insertion == "states('sensor.solar_power')")
    }

    @Test func insertionInsideOpenQuoteReplacesTypedPrefix() {
        let text = "{{ is_state('sens"
        let insertion = provider.entityInsertion(
            for: "sensor.solar_power",
            text: text,
            cursorLocation: (text as NSString).length
        )
        #expect(insertion.insertion == "sensor.solar_power")
        #expect(insertion.replacingCount == 4)
    }

    // MARK: - Inline entity references

    @Test func entityReferencesFindKnownEntityIdsInsideQuotes() {
        let text = "{{ states('sensor.solar_power') }} and {{ is_state(\"light.kitchen\", 'on') }}"
        let references = provider.entityReferences(in: text)

        #expect(references.map(\.entityId) == ["sensor.solar_power", "light.kitchen"])
        #expect((text as NSString).substring(with: references[0].range) == "sensor.solar_power")
        #expect((text as NSString).substring(with: references[1].range) == "light.kitchen")
    }

    @Test func entityReferencesIgnoreUnknownStrings() {
        let text = "{{ states('sensor.unknown') }} {{ is_state('light.kitchen', 'on') }}"
        #expect(provider.entityReferences(in: text).map(\.entityId) == ["light.kitchen"])
    }

    @Test func entityReferenceAtLocationReturnsTappedEntity() {
        let text = "{{ states('sensor.solar_power') }} and {{ states('light.kitchen') }}"
        let location = (text as NSString).range(of: "light.kitchen").location

        #expect(provider.entityReference(in: text, at: location)?.entityId == "light.kitchen")
        #expect(provider.entityReference(in: text, at: 0) == nil)
    }
}
