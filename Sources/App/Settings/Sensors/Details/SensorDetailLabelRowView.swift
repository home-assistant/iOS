import SwiftUI

struct SensorDetailLabelRowView: View {
    let attribute: String
    let value: Any

    var body: some View {
        HStack {
            Text(attribute)
            Spacer()
            Text(displayValue)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        #if !os(watchOS)
        .textSelection(.enabled)
        #endif
    }

    private var displayValue: String {
        if let number = value as? NSNumber, number === kCFBooleanTrue || number === kCFBooleanFalse {
            return String(describing: number.boolValue)
        }
        return String(describing: value)
    }
}

#Preview {
    List {
        SensorDetailLabelRowView(attribute: "Stream URL", value: "http://192.168.1.20:8090/camera")
        SensorDetailLabelRowView(attribute: "Clients", value: 1)
        SensorDetailLabelRowView(attribute: "Motion", value: true)
    }
}
