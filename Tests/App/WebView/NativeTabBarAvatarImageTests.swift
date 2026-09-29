import Foundation
@testable import HomeAssistant
import Testing
import UIKit

struct NativeTabBarAvatarImageTests {
    private func solidPicture(_ color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    @Test("The avatar is rendered at the requested size and keeps its own colours in a bar")
    func sizeAndRenderingMode() {
        let avatar = NativeTabBarAvatarImage.circular(nil, initial: "Bruno", size: 24)
        #expect(avatar.size == CGSize(width: 24, height: 24))
        #expect(avatar.renderingMode == .alwaysOriginal)
        #expect(avatar.cgImage != nil)
    }

    @Test("Without a picture the avatar shows the user's initial, so different users look different")
    func initialsFallback() {
        let bruno = NativeTabBarAvatarImage.circular(nil, initial: "bruno", size: 24)
        let ana = NativeTabBarAvatarImage.circular(nil, initial: "Ana", size: 24)
        let nobody = NativeTabBarAvatarImage.circular(nil, initial: "", size: 24)
        #expect(bruno.pngData() != ana.pngData())
        #expect(nobody.cgImage != nil)
    }

    @Test("A picture fills the circle whatever its aspect ratio")
    func pictureFillsTheCircle() {
        let wide = solidPicture(.red, size: CGSize(width: 200, height: 50))
        let tall = solidPicture(.red, size: CGSize(width: 50, height: 200))
        let fromWide = NativeTabBarAvatarImage.circular(wide, initial: "B", size: 24)
        let fromTall = NativeTabBarAvatarImage.circular(tall, initial: "B", size: 24)
        let initials = NativeTabBarAvatarImage.circular(nil, initial: "B", size: 24)
        #expect(fromWide.size == CGSize(width: 24, height: 24))
        #expect(fromWide.pngData() == fromTall.pngData())
        #expect(fromWide.pngData() != initials.pngData())
    }
}
