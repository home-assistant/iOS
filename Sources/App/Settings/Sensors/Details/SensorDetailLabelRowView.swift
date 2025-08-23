import SwiftUI

struct SensorDetailLabelRowView: View {
    let attribute: String
    let value: Any

    var body: some View {
        HStack {
            Text(attribute)
            Spacer()
            if let number = value as? NSNumber, number === kCFBooleanTrue || number === kCFBooleanFalse {
                Text(String(describing: number.boolValue))
                    .foregroundColor(.secondary)
            } else {
                Text(String(describing: value))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
