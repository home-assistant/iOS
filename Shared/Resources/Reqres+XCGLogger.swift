//
//  Reqres+XCGLogger.swift
//  Shared
//
//  Created by Robert Trencheny on 2/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Reqres

class ReqresXCGLogger: ReqresLogging {
    open var logLevel: LogLevel = .verbose

    func logVerbose(_ message: String) {
        Current.Log.verbose(message)
    }
    func logLight(_ message: String) {
        Current.Log.info(message)
    }
    func logError(_ message: String) {
        Current.Log.error(message)
    }
}
