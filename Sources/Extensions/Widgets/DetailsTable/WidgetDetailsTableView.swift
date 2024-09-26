import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetDetailsTableView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    var entry: WidgetDetailsTableEntry

    var body: some View {
        Text("hello")

        VStack(alignment: .leading) {
            Text("hello")
            ForEach(entry.sensorData, id: \.key) { sensorData in
                HStack {
                    Text(sensorData.key)
                    Spacer()
                    Text(sensorData.value)
                }
            }
        }
    }
}
