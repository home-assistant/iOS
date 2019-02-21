//
//  Reqres+CleanroomLogger.swift
//  Shared
//
//  Created by Robert Trencheny on 2/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Reqres
import CleanroomLogger

class ReqresCleanroom: ReqresLogging {
    open var logLevel: LogLevel = .verbose

    func logVerbose(_ message: String) {
        Log.verbose?.message(message)
    }
    func logLight(_ message: String) {
        Log.info?.message(message)
    }
    func logError(_ message: String) {
        Log.error?.message(message)
    }
}
