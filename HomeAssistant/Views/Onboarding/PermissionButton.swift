//
//  PermissionButton.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//
//  Slightly modified from SPPermission's button: https://bit.ly/2UMXEtN

import UIKit

@IBDesignable class PermissionButton: UIButton {

    var style: Style = .default {
        didSet {
            self.setTitleColorForTwoState(self.style.textColor)
            self.setTitle(self.style.title, for: .normal)

            self.backgroundColor = self.style.backgroundColor
            self.contentEdgeInsets = self.style.insets(self.titleLabel?.text?.count)

            self.sizeToFit()
        }
    }

    init() {
        super.init(frame: .zero)
        self.sharedInit()
    }

    required override init(frame: CGRect) {
        super.init(frame: frame)
        self.sharedInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.sharedInit()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.sharedInit()
    }

    func sharedInit() {
        self.style = .default
        self.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        self.layer.masksToBounds = true
        self.layer.cornerRadius = self.frame.height / 2
    }

    override func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title?.uppercased(), for: state)
    }

    private func setTitleColorForTwoState(_ color: UIColor) {
        self.setTitleColor(color, for: .normal)
        self.setTitleColor(color.withAlphaComponent(0.7), for: .highlighted)
    }

    enum Style {
        case `default`
        case allowed

        var backgroundColor: UIColor {
            switch self {
            case .default: // Light grey - #f0f1f6
                return #colorLiteral(red: 0.941176471, green: 0.945098039, blue: 0.964705882, alpha: 1)
            case .allowed: // Blue - #0076ff
                return #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
            }
        }

        var textColor: UIColor {
            switch self {
            case .default: // Blue - #0076ff
                return #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
            case .allowed: // Light grey - #f0f1f6
                return #colorLiteral(red: 0.941176471, green: 0.945098039, blue: 0.964705882, alpha: 1)
            }
        }

        func insets(_ characterCount: Int?) -> UIEdgeInsets {
            if self == .default && characterCount ?? 5 < 4 {
                return UIEdgeInsets.init(top: 6, left: 22, bottom: 6, right: 22)
            }
            return UIEdgeInsets(top: 6, left: 15, bottom: 6, right: 15)
        }

        var title: String {
            switch self {
            case .default:
                return "Allow"
            case .allowed:
                return "Allowed"
            }
        }
    }
}
