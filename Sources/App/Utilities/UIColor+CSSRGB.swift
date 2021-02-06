import Foundation
import UIKit

public extension UIColor {
    convenience init?(rgbString string: String) {
        guard let pattern = try? NSRegularExpression(
            pattern: #"rgb(?:a){0,1}\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([0-9\.]+))*\)"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        guard let match = pattern.firstMatch(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.utf16.count)
        ) else {
            return nil
        }

        let values = (1 ..< match.numberOfRanges)
            .map { match.range(at: $0) }
            .filter { $0.location != NSNotFound }
            .map { (string as NSString).substring(with: $0) }
            .compactMap { (numberString: String) -> Float? in
                let scanner = Scanner(string: numberString)
                if #available(iOS 13, *) {
                    return scanner.scanFloat()
                } else {
                    var result: Float = 0
                    if scanner.scanFloat(&result) {
                        return result
                    } else {
                        return nil
                    }
                }
            }.map { CGFloat($0) }

        guard values.count >= 3 else {
            return nil
        }

        func clamp(_ value: CGFloat) -> CGFloat {
            min(1.0, max(0.0, value))
        }

        self.init(
            red: clamp(values[0] / 255.0),
            green: clamp(values[1] / 255.0),
            blue: clamp(values[2] / 255.0),
            alpha: values.count == 4 ? clamp(values[3]) : 1.0
        )
    }
}
