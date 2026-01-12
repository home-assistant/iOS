import SFSafeSymbols
import SwiftUI

@available(iOS 18, *)
struct Toast {
    private(set) var id: String
    var symbol: SFSymbol
    var symbolFont: Font
    var symbolForegroundStyle: (Color, Color)

    var title: String
    var message: String

    init(
        id: String = UUID().uuidString,
        symbol: SFSymbol,
        symbolFont: Font = .system(size: 35),
        symbolForegroundStyle: (Color, Color),
        title: String,
        message: String
    ) {
        self.id = id
        self.symbol = symbol
        self.symbolFont = symbolFont
        self.symbolForegroundStyle = symbolForegroundStyle
        self.title = title
        self.message = message
    }

    static var example1: Toast {
        Toast(
            symbol: .checkmarkSealFill,
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .green),
            title: "Transaction Success!",
            message: "Your transaction with iJustine is complete"
        )
    }

    static var example2: Toast {
        Toast(
            symbol: .xmarkSealFill,
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .red),
            title: "Transaction Failed!",
            message: "Your transaction with iJustine has failed"
        )
    }
}
