//
//  ActionButtonProvider.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

public protocol ActionButtonProviderProtocol {
    var delegate: ActionButtonProviderDelegate? { get set }
    func actionButton(for url: URL, given actionButton: UIButton)
}

public protocol ActionButtonProviderDelegate: AnyObject {
    func didTapAppleThreadCredentials()
}

public final class ActionButtonProvider: ActionButtonProviderProtocol {

    enum KnownPath: String, CaseIterable {
        case thread = "/config/thread"
    }

    weak public var delegate: ActionButtonProviderDelegate?

    public func actionButton(for url: URL, given actionButton: UIButton) {
        actionButton.isHidden = true
        KnownPath.allCases.forEach { path in
            if url.relativePath.contains(path.rawValue) {
                prepareButton(actionButton, pathType: path)
            }
        }
    }

    private func prepareButton(_ button: UIButton, pathType: KnownPath) {
        switch pathType {
        case .thread:
            if #available(iOS 16.4, *) {
                button.setTitle(" Credentials", for: .normal)
                button.addTarget(self, action: #selector(didTapAppleThreadCredentials), for: .touchUpInside)
                button.isHidden = false
            }
        }
    }

    // MARK: - Tap events
    @objc private func didTapAppleThreadCredentials() {
        delegate?.didTapAppleThreadCredentials()
    }
}
