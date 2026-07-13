import SFSafeSymbols
import SwiftUI

@available(iOS 18, *)
public struct Toast {
    private(set) var id: String
    public var symbol: SFSymbol
    public var symbolFont: Font
    public var symbolForegroundStyle: (Color, Color)

    public var title: String
    public var message: String

    public init(
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

    public static var example1: Toast {
        Toast(
            symbol: .checkmarkSealFill,
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .green),
            title: "Transaction Success!",
            message: "Your transaction with iJustine is complete"
        )
    }

    public static var example2: Toast {
        Toast(
            symbol: .xmarkSealFill,
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .red),
            title: "Transaction Failed!",
            message: "Your transaction with iJustine has failed"
        )
    }
}
