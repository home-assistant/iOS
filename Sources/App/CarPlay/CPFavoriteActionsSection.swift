//
//  CPFavoriteActionsSection.swift
//  App
//
//  Created by Bruno Pantaleão on 30/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import CarPlay
import Shared
import RealmSwift

@available(iOS 15.0, *)
final class CPFavoriteActionsSection {

    private var noActionsView: CPInformationTemplate = {
        CPInformationTemplate(
            title: L10n.About.Logo.title,
            layout: .leading,
            items: [
                .init(title: L10n.CarPlay.NoActions.title, detail: nil)
            ],
            actions: []
        )
    }()

    func list(for actions: Results<Action>) -> CPTemplate {
        if actions.isEmpty {
            noActionsView
        } else {
            CPListTemplate.init(
                title: L10n.SettingsDetails.Actions.title, sections: [
                    section(actions: actions)
                ]
            )
        }
    }

    private func section(actions: Results<Action>) -> CPListSection {
        let items: [CPListItem] = actions.map { action in
            let materialDesignIcon = MaterialDesignIcons(named: action.IconName).image(ofSize: CPListItem.maximumImageSize, color: UIColor(hex: action.IconColor))
            let croppedIcon = cropImageToSquare(image: materialDesignIcon)!
            let carPlayIcon = carPlayImage(from: croppedIcon)!
            let item = CPListItem(
                text: action.Name,
                detailText: action.Text,
                image: carPlayIcon
            )
            item.handler = { _, completion in
                guard let server = Current.servers.server(for: action) else {
                    completion()
                    return
                }
                Current.api(for: server).HandleAction(actionID: action.ID, source: .CarPlay).pipe { result in
                    switch result {
                    case .fulfilled:
                        break
                    case .rejected(let error):
                        Current.Log.info(error)
                    }
                    completion()
                }
            }
            return item
        }

        return  CPListSection(items: items)
    }
}

// MARK: - CarPlay Image Resize
@available(iOS 15.0, *)
extension CPFavoriteActionsSection {
    private func carPlayImage(from image: UIImage) -> UIImage? {
      let imageAsset = UIImageAsset()
        imageAsset.register(image, with: .current)
        return imageAsset.image(with: .current)
    }


    private func resizeImage(image: UIImage, newSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resizedImage
    }

    private func cropImageToSquare(image: UIImage) -> UIImage? {
        let originalSize = image.size
        let squareSize = min(originalSize.width, originalSize.height)
        let newSize = CGSize(width: squareSize, height: squareSize)
        let origin = CGPoint(x: (originalSize.width - squareSize) / 2, y: (originalSize.height - squareSize) / 2)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let croppedImage = renderer.image { context in
            image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }

        return croppedImage
    }
}
