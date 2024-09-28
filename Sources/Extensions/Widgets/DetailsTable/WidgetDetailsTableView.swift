import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetDetailsTableView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    var entry: WidgetDetailsTableEntry

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(entry.sensorData.indices, id: \.self) { index in
                let sensorData = entry.sensorData[index]
                
                HStack {
                    Text(sensorData.key)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(sensorData.value) \(sensorData.unitOfMeasurement ?? "")")
                        .font(.system(size: 13))
                }
                
                // Add a divider only if there's a next entry
                if index < entry.sensorData.count - 1 {
                    Divider()
                        .background(Color.gray.opacity(0.5))
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal)
    }

}
