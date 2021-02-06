import CoreMotion
import Foundation

// Don't translate these strings as they are sent to HA and we don't want to cause people to have to write
// automations expecting localized strings.

extension CMMotionActivity {
    var activityTypes: [String] {
        var types: [String] = []

        if walking {
            types.append("Walking")
        } else if running {
            types.append("Running")
        } else if automotive {
            types.append("Automotive")
        } else if cycling {
            types.append("Cycling")
        } else if stationary {
            types.append("Stationary")
        } else {
            types.append("Unknown")
        }

        return types
    }

    var icons: [String] {
        var icons: [String] = []

        if walking {
            icons.append("mdi:walk")
        } else if running {
            icons.append("mdi:run")
        } else if automotive {
            icons.append("mdi:car")
        } else if cycling {
            icons.append("mdi:bike")
        } else if stationary {
            icons.append("mdi:human-male")
        } else {
            icons.append("mdi:help-circle")
        }

        return icons
    }
}

extension CMMotionActivityConfidence {
    var description: String {
        if self == CMMotionActivityConfidence.low {
            return "Low"
        } else if self == CMMotionActivityConfidence.medium {
            return "Medium"
        } else if self == CMMotionActivityConfidence.high {
            return "High"
        }
        return "Unknown"
    }
}
