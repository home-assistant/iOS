//
//  ThreadCredentialsSharing+build.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import Shared

@available(iOS 16.4, *)
extension ThreadCredentialsSharingView {
    static func build(server: Server) -> ThreadCredentialsSharingView {
        .init(
            viewModel: .init(
                server: server,
                threadClient: ThreadClientService()
            )
        )
    }
}
