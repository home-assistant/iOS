import Foundation

public extension NSMutableAttributedString {
    func addMissingAttributes(_ attributes: [Key: Any]) {
        let range = NSRange(location: 0, length: string.utf16.count)
        for (key, newValue) in attributes {
            enumerateAttribute(key, in: range, options: []) { value, range, _ in
                if value == nil {
                    addAttribute(key, value: newValue, range: range)
                }
            }
        }
    }
}
