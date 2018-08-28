//
//  CMMotion+StringExtensions.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 8/6/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import CoreMotion

extension CMMotionActivity {
    var activityType: String {
        if self.walking {
            return "Walking"
        } else if self.running {
            return "Running"
        } else if self.automotive {
            return "Automotive"
        } else if self.cycling {
            return "Cycling"
        } else if self.stationary {
            return "Stationary"
        } else {
            return "Unknown"
        }
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
