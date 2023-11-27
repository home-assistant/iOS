import Foundation
import SwiftUI
import UIKit

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

    public weak var delegate: ActionButtonProviderDelegate?

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
