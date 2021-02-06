import PromiseKit
@testable import Shared
import XCTest

class AuthorizationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

//    func testExample() {
//        let exp = self.expectation(description: "yo")
//
//        firstly {
//            AuthenticationAPI.listProviders()
//            }.then { providers in
    // AuthenticationAPI.authenticationForm(for: providers.first!)
//            }.then { form in
//                AuthenticationAPI.postAuthenticationResponses(["username": "stephen", "password":"password"],
//                                                              flowId: form.flowId)
//            }.done { response in
//                switch response {
//                case .invalid(let form):
//                    print(form)
//                case .valid(_, _, let code):
//                AuthenticationAPI.fetchTokenWithCode(code).done { dictionary in
//                        print(dictionary)
//                    }
//                }
//
//        }
//
//        self.wait(for: [exp], timeout: 10.0)
//    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
