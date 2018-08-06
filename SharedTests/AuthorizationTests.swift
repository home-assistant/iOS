//
//  AuthorizationTests.swift
//  SharedTests
//
//  Created by Stephan Vanterpool on 7/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import XCTest
import Alamofire
import PromiseKit
@testable import Shared

class AuthorizationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let exp = self.expectation(description: "yo")
        firstly {
            AuthenticationAPI.listProviders()
            }.then { (providers: [AuthenticationProvider]) in
            print(providers)
        }

        self.wait(for: [exp], timeout: 10.0)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
