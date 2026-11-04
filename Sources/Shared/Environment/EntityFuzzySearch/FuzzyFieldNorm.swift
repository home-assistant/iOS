import Foundation

enum FuzzyFieldNorm {
    static func value(_ text: String, weight: Double = 1, mantissa: Int = 3) -> Double {
        var tokenCount = 1
        var inSpace = false
        for unit in text.utf16 {
            if unit == 32 {
                if !inSpace { tokenCount += 1; inSpace = true }
            } else {
                inSpace = false
            }
        }
        let m = pow(10.0, Double(mantissa))
        return (m / pow(Double(tokenCount), 0.5 * weight)).rounded() / m
    }
}
