import Foundation
@testable import Shared
import Testing

struct LocalizedStringResourceVerbatimTests {
    @Test(arguments: [
        "Living room lamp",
        "100% lamp",
        "\"Quoted\" %@ %d name",
        "Lamp = \"on\";",
    ])
    func aVerbatimResourceResolvesToTheStringItWasGiven(name: String) {
        #expect(String(localized: .verbatim(name)) == name)
    }

    @Test func aVerbatimResourceSkipsTheMainStringsTable() {
        let resource: LocalizedStringResource = .verbatim("Living room lamp")
        #expect(resource.table == LocalizedStringResource.verbatimTable)
        #expect(Bundle.main.url(forResource: LocalizedStringResource.verbatimTable, withExtension: "strings") == nil)
    }
}
