@testable import Shared
import SwiftUI
import Testing

struct ToastTests {
    @available(iOS 18, *)
    @Test func successExampleDescribesACompletedTransaction() {
        let toast = Toast.example1

        #expect(toast.symbol.rawValue == "checkmark.seal.fill")
        #expect(toast.symbolForegroundStyle.0 == .white)
        #expect(toast.symbolForegroundStyle.1 == .green)
        #expect(toast.title == "Transaction Success!")
        #expect(toast.message == "Your transaction with iJustine is complete")
        #expect(!toast.id.isEmpty)
    }

    @available(iOS 18, *)
    @Test func failureExampleDescribesAFailedTransaction() {
        let toast = Toast.example2

        #expect(toast.symbol.rawValue == "xmark.seal.fill")
        #expect(toast.symbolForegroundStyle.0 == .white)
        #expect(toast.symbolForegroundStyle.1 == .red)
        #expect(toast.title == "Transaction Failed!")
        #expect(toast.message == "Your transaction with iJustine has failed")
    }

    @available(iOS 18, *)
    @Test func eachToastGetsItsOwnIdentifierUnlessOneIsGiven() {
        #expect(Toast.example1.id != Toast.example1.id)

        let toast = Toast(
            id: "fixed-id",
            symbol: Toast.example1.symbol,
            symbolForegroundStyle: (.white, .blue),
            title: "Title",
            message: "Message"
        )
        #expect(toast.id == "fixed-id")
        #expect(toast.title == "Title")
        #expect(toast.message == "Message")
    }
}
