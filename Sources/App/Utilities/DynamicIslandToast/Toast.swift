import SwiftUI

@available(iOS 18, *)
struct Toast {
    private(set) var id: String = UUID().uuidString
    var symbol: String
    var symbolFont: Font
    var symbolForegroundStyle: (Color, Color)

    var title: String
    var message: String

    static var example1: Toast {
        Toast(
            symbol: "checkmark.seal.fill",
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .green),
            title: "Transaction Success!",
            message: "Your transaction with iJustine is complete"
        )
    }

    static var example2: Toast {
        Toast(
            symbol: "xmark.seal.fill",
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .red),
            title: "Transaction Failed!",
            message: "Your transaction with iJustine is failed"
        )
    }
}
