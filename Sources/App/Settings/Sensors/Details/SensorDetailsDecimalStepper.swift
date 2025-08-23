import Shared
import SwiftUI

struct SensorDetailsDecimalStepper: View {
    let title: String
    @Binding var value: Double
    let minimum: Double
    let maximum: Double
    let step: Double
    let displayValueFor: ((Double?) -> String?)?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(
                onIncrement: {
                    var newValue = value + step
                    if newValue > maximum { newValue = maximum }
                    value = newValue
                },
                onDecrement: {
                    var newValue = value - step
                    if newValue < minimum { newValue = minimum }
                    value = newValue
                }
            ) {
                if let displayValueFor {
                    Text(displayValueFor(value) ?? L10n.unknownLabel)
                } else {
                    Text("\(value)")
                }
            }
        }
    }
}
