//
//  PermissionLineItemView.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Lottie
import Shared

protocol PermissionViewChangeDelegate: class {
    func statusChanged(_ forPermission: PermissionType, _ toStatus: PermissionStatus)
}

@IBDesignable class PermissionLineItemView: UIView {

    let titleLabel = UILabel()
    let descriptionLabel = UILabel()
    var animationView = AnimationView()
    var button = PermissionButton()
    // var separatorView = UIView()

    var permission: PermissionType = PermissionType.location

    weak var delegate: PermissionViewChangeDelegate?

    @IBInspectable var permissionInt: Int = PermissionType.location.rawValue {
        didSet {
            guard let permission = PermissionType(rawValue: self.permissionInt) else {
                fatalError("Invalid permission int \(self.permissionInt)")
            }

            self.permission = permission
            self.titleLabel.text = permission.title
            self.descriptionLabel.text = permission.description
            self.animationView.animation = permission.animation
            self.commonInit()
        }
    }

    init(permission: PermissionType) {
        self.permission = permission
        super.init(frame: .zero)

        self.commonInit()
    }

    required override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.commonInit()
    }

    @objc func buttonTapped(_ sender: PermissionButton) {
        self.permission.request { (success, newStatus) in
            let newStyle: PermissionButton.Style = success ? .allowed : .default
            UIView.animate(withDuration: 0.2) {
                self.button.style = newStyle
            }
            self.delegate?.statusChanged(self.permission, newStatus)
        }
    }

    private func commonInit() {
        self.animationView.contentMode = .scaleAspectFill
        self.animationView.loopMode = .loop
        self.animationView.backgroundBehavior = .pauseAndRestore
        self.animationView.play()

        self.backgroundColor = .clear

        self.addSubview(self.animationView)

        self.titleLabel.numberOfLines = 1
        self.titleLabel.textColor = .white
        self.titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        self.addSubview(self.titleLabel)

        self.descriptionLabel.numberOfLines = 3
        self.descriptionLabel.textColor = .white
        self.descriptionLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        self.addSubview(self.descriptionLabel)

        self.button.addTarget(self, action: #selector(self.buttonTapped(_:)), for: .touchUpInside)

        self.button.style = self.permission.isAuthorized ? .allowed : .default
        self.addSubview(self.button)

        // self.separatorView.backgroundColor = .white
        // self.addSubview(self.separatorView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.frame = CGRect(origin: self.frame.origin, size: CGSize(width: self.frame.width, height: 120))

        self.animationView.frame = CGRect(x: 0, y: 0, width: 75, height: 75)
        self.animationView.center.y = self.frame.height / 2

        self.button.sizeToFit()
        self.button.frame.origin.x = self.frame.width - self.button.frame.width
        self.button.center.y = self.frame.height / 2

        // swiftlint:disable line_length
        let titleInset: CGFloat = 15
        let titlesWidth: CGFloat = self.button.frame.origin.x - (self.animationView.frame.origin.x + self.animationView.frame.width) - titleInset * 2

        self.titleLabel.frame = CGRect(x: 0, y: 8, width: titlesWidth, height: 0)
        self.titleLabel.sizeToFit()
        self.titleLabel.frame = CGRect(origin: self.titleLabel.frame.origin, size: CGSize(width: titlesWidth, height: self.titleLabel.frame.height))
        self.titleLabel.frame.origin.x = (self.animationView.frame.origin.x + self.animationView.frame.width) + titleInset

        self.descriptionLabel.frame = CGRect(x: self.titleLabel.frame.origin.x + titleInset, y: 0, width: titlesWidth, height: 0)
        self.descriptionLabel.sizeToFit()
        self.descriptionLabel.frame = CGRect(origin: self.descriptionLabel.frame.origin, size: CGSize(width: titlesWidth, height: self.descriptionLabel.frame.height))
        self.descriptionLabel.frame.origin.x = self.animationView.frame.origin.x + self.animationView.frame.width + titleInset

        let allHeight = self.titleLabel.frame.height + 2 + self.descriptionLabel.frame.height
        self.titleLabel.frame.origin.y = (self.frame.height - allHeight) / 2
        self.descriptionLabel.frame.origin.y = self.titleLabel.frame.origin.y + self.titleLabel.frame.height + 2

        // self.separatorView.frame = CGRect(x: self.descriptionLabel.frame.origin.x, y: self.frame.height - 0.7, width: self.button.frame.origin.x + self.button.frame.width - self.descriptionLabel.frame.origin.x, height: 0.7)
        // self.separatorView.layer.cornerRadius = self.separatorView.frame.height / 2
    }
}
