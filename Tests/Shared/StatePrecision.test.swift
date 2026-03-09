import Foundation
@testable import Shared
import Testing

@Suite("State Precision Tests")
struct StatePrecisionTests {
    @Test("Given grouped thousands and zero decimal places when adjusted then keeps full integer value with grouping")
    func groupedThousandsWithZeroDecimals() {
        let result = StatePrecision.adjustPrecision(
            stateValue: "2.448",
            decimalPlaces: 0,
            locale: Locale(identifier: "de_DE")
        )

        #expect(result == "2.448")
    }

    @Test("Given decimal state value and zero decimal places when adjusted then rounds with locale grouping")
    func decimalValueWithZeroDecimalsAndGrouping() {
        let result = StatePrecision.adjustPrecision(
            stateValue: "2448.4",
            decimalPlaces: 0,
            locale: Locale(identifier: "en_US")
        )

        #expect(result == "2,448")
    }

    @Test("Given negative integer value when adjusted then keeps sign and locale thousands separator")
    func negativeIntegerWithGrouping() {
        let result = StatePrecision.adjustPrecision(
            stateValue: "-7418",
            decimalPlaces: 0,
            locale: Locale(identifier: "en_US")
        )

        #expect(result == "-7,418")
    }

    @Test("Given signed grouped value with dot separator when adjusted then keeps full integer magnitude")
    func signedGroupedValueWithDotSeparator() {
        let result = StatePrecision.adjustPrecision(
            stateValue: "-7.418",
            decimalPlaces: 0,
            locale: Locale(identifier: "de_DE")
        )

        #expect(result == "-7.418")
    }

    @Test("Given signed grouped value with comma separator when adjusted then keeps full integer magnitude")
    func signedGroupedValueWithCommaSeparator() {
        let result = StatePrecision.adjustPrecision(
            stateValue: "-7,418",
            decimalPlaces: 0,
            locale: Locale(identifier: "en_US")
        )

        #expect(result == "-7,418")
    }

    @Test("Given comma decimal state value in locale when adjusted then keeps locale decimals without grouping")
    func localizedDecimalValue() {
        let result = StatePrecision.adjustPrecision(
            stateValue: "12,34",
            decimalPlaces: 1,
            locale: Locale(identifier: "de_DE")
        )

        #expect(result == "12,3")
    }
}
