@testable import Shared
import Testing
import UIKit

struct SharedAssetsTests {
    private static let assets: [ImageAsset] = [
        Asset.logo,
        Asset.casitaDark,
        Asset.casita,
        Asset.haCloudLogo,
        Asset.improvLogo,
        Asset.logoHorizontalText,
        Asset.statusItemIcon,
        Asset.thread,
    ]

    @Test func everyAssetIsBundledWithShared() {
        for asset in Self.assets {
            #expect(asset.image.size.width > 0, "\(asset.name)")
            #expect(UIImage(asset: asset) != nil, "\(asset.name)")
        }
    }

    @Test func assetsResolveForEitherAppearance() {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)

        for asset in Self.assets {
            #expect(asset.image(compatibleWith: dark).size.width > 0, "\(asset.name)")
            #expect(asset.image(compatibleWith: light).size.width > 0, "\(asset.name)")
        }
    }

    @Test func namesMatchTheAssetCatalog() {
        #expect(Asset.logo.name == "Logo")
        #expect(Asset.casitaDark.name == "casita-dark")
        #expect(Asset.haCloudLogo.name == "ha-cloud-logo")
        #expect(Asset.statusItemIcon.name == "statusItemIcon")
    }
}
