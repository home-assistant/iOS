//
//  CrashlyticsLogDestination.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/5/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import XCGLogger
import FirebaseCrashlytics

open class CrashlyticsLogDestination: BaseQueuedDestination {

    // MARK: - Overridden Methods
    /// Print the log to the Apple System Log facility (using NSLog).
    ///
    /// - Parameters:
    ///     - message:   Formatted/processed message ready for output.
    ///
    /// - Returns:  Nothing
    ///
    open override func write(message: String) {

        let outputClosure = {
            let aTextArray: [CVarArg] = [message]
            Crashlytics.crashlytics().log(format: "%@", arguments: getVaList(aTextArray))
        }

        if let logQueue = logQueue {
            logQueue.async(execute: outputClosure)
        } else {
            outputClosure()
        }
    }
}
