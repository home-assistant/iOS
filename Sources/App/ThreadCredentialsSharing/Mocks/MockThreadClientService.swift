//
//  MockThreadClientService.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation

@available(iOS 13, *)
final class MockThreadClientService: THClientProtocol {
    var retrieveAllCredentialsCalled = false
    
    func retrieveAllCredentials() async throws -> [ThreadCredential] {
        retrieveAllCredentialsCalled = true
        return [
            .init(
                networkName: "test",
                networkKey: "test",
                extendedPANID: "test",
                borderAgentID: "test",
                activeOperationalDataSet: "test",
                pskc: "test",
                channel: 25,
                panID: "test",
                creationDate: nil,
                lastModificationDate: Date()
            ),
            .init(
                networkName: "test",
                networkKey: "test",
                extendedPANID: "test",
                borderAgentID: "test2",
                activeOperationalDataSet: "test",
                pskc: "test",
                channel: 25,
                panID: "test",
                creationDate: nil,
                lastModificationDate: Date()
            )
        ]
    }
}
