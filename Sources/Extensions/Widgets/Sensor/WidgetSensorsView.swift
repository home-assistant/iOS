import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetSensorsView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    var entry: WidgetSensorsEntry

    private static let maxItems: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.sensorData.count != WidgetSensorsView.maxItems {
                resizedLogoView()
                Spacer()
            }

            ForEach(entry.sensorData.indices, id: \.self) { index in
                let sensorData = entry.sensorData[index]

                sensorDataView(sensorData: sensorData)

                // Add a divider only if there's a next entry
                if index < entry.sensorData.count - 1 {
                    Divider()
                        .background(Color.gray.opacity(0.5))
                }
            }
        }.padding(.all)
    }

    func sensorDataView(sensorData: WidgetSensorsEntry.SensorData) -> some View {
        HStack {
            Text(sensorData.key)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Spacer()
            Text("\(sensorData.value) \(sensorData.unitOfMeasurement ?? "")")
                .font(.system(size: 11))
                .bold()
        }
    }

    func resizedLogoView() -> some View {
        HStack {
            Image(uiImage: Asset.SharedAssets.logo.image)
                .resizable()
                .frame(width: 30, height: 30)
            Spacer()
        }
    }
}
