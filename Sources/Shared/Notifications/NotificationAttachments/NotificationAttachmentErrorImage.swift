import Foundation

#if os(iOS)
enum NotificationAttachmentErrorImage {
    static func saveImage(
        for error: Error,
        savingTo destination: URL
    ) throws -> String {
        let string = Self.errorString(for: error)
        try Self.saveImage(
            for: Self.errorString(for: error),
            writingToURL: destination
        )
        return string.string
    }

    private static func errorString(for error: Error) -> NSAttributedString {
        let message = NSMutableAttributedString()

        message.append(NSAttributedString(string: L10n.NotificationService.failedToLoad, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .title3),
            .foregroundColor: UIColor.red,
        ]))
        message.append(NSAttributedString(string: "\n" + error.localizedDescription, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.black,
        ]))

        message.addAttributes([
            .paragraphStyle: with(NSMutableParagraphStyle()) {
                $0.alignment = .center
            },
        ], range: NSRange(location: 0, length: message.length))

        return message
    }

    private static func saveImage(for message: NSAttributedString, writingToURL temporaryURL: URL) throws {
        let padding: CGFloat = 20
        let width: CGFloat = 320

        let stringRect = message
            .boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                context: nil
            )
            .offsetBy(dx: padding, dy: padding)
            .integral
        let rendererRect = stringRect
            .insetBy(dx: -padding, dy: -padding)

        try UIGraphicsImageRenderer(size: rendererRect.size, format: UIGraphicsImageRendererFormat.preferred())
            .pngData { context in
                UIColor.white.setFill()
                context.fill(rendererRect)
                message.draw(with: stringRect, options: [.usesLineFragmentOrigin], context: nil)
            }
            .write(to: temporaryURL)
    }
}
#endif
