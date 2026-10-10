import Foundation
@testable import Shared
import SwiftUI
import Testing

struct ColorCodableTests {
    @Test func roundTripsThroughJSON() throws {
        let color = Color(red: 0.25, green: 0.5, blue: 0.75)

        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(Color.self, from: data)

        let components = try #require(UIColor(decoded).cgColor.components)
        #expect(abs(components[0] - 0.25) < 0.01)
        #expect(abs(components[1] - 0.5) < 0.01)
        #expect(abs(components[2] - 0.75) < 0.01)
    }
}
