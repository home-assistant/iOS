import SFSafeSymbols
@testable import Shared
import Testing
import UIKit

/// The picker draws these per row, so a name that resolves to nothing would leave the list blank.
struct DomainSFSymbolTests {
    @Test func everyDomainResolvesToASymbolTheSystemCanDraw() {
        for domain in Domain.allCases {
            let name = domain.sfSymbolName
            #expect(!name.isEmpty, "\(domain.rawValue) has no symbol")
            #expect(UIImage(systemName: name) != nil, "\(domain.rawValue) maps to \(name), which does not render")
        }
    }

    /// The domains a spoken command reaches are the ones worth reading at a glance, so they get
    /// something recognisable rather than the fallback.
    @Test func theVoiceDomainsGetTheirOwnSymbol() {
        #expect(Domain.light.sfSymbolName == SFSymbol.lightbulb.rawValue)
        #expect(Domain.lock.sfSymbolName == SFSymbol.lock.rawValue)
        #expect(Domain.cover.sfSymbolName == SFSymbol.blindsHorizontalClosed.rawValue)
        #expect(Domain.climate.sfSymbolName == SFSymbol.thermometerMedium.rawValue)
        #expect(Domain.fan.sfSymbolName == SFSymbol.fanblades.rawValue)
    }
}
