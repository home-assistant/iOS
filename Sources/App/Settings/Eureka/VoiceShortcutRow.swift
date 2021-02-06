import Eureka
import Foundation
import IntentsUI
import Shared

@available(iOS 13.0, *)
public class VoiceShortcutCell: Cell<INShortcut>, CellType,
    INUIAddVoiceShortcutButtonDelegate,
    INUIAddVoiceShortcutViewControllerDelegate,
    INUIEditVoiceShortcutViewControllerDelegate {
    private let button = INUIAddVoiceShortcutButton(style: .automatic)

    fileprivate var shortcutRow: VoiceShortcutRow? { row as? VoiceShortcutRow }

    override public func setup() {
        super.setup()
        selectionStyle = .none

        contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false

        let margins = contentView.layoutMarginsGuide

        isAccessibilityElement = false // container
        textLabel?.isHidden = true

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: margins.topAnchor),
            button.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            button.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            button.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
        ])

        button.delegate = self
    }

    override public func update() {
        super.update()
        button.setStyle(shortcutRow?.buttonStyle ?? .automatic)
        button.shortcut = row.value
    }

    public func present(
        _ addVoiceShortcutViewController: INUIAddVoiceShortcutViewController,
        for addVoiceShortcutButton: INUIAddVoiceShortcutButton
    ) {
        addVoiceShortcutViewController.delegate = self
        formViewController()?.present(addVoiceShortcutViewController, animated: true, completion: nil)
    }

    public func present(
        _ editVoiceShortcutViewController: INUIEditVoiceShortcutViewController,
        for addVoiceShortcutButton: INUIAddVoiceShortcutButton
    ) {
        editVoiceShortcutViewController.delegate = self
        formViewController()?.present(editVoiceShortcutViewController, animated: true, completion: nil)
    }

    public func addVoiceShortcutViewController(
        _ controller: INUIAddVoiceShortcutViewController,
        didFinishWith voiceShortcut: INVoiceShortcut?,
        error: Error?
    ) {
        controller.dismiss(animated: true, completion: nil)
    }

    public func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

    public func editVoiceShortcutViewController(
        _ controller: INUIEditVoiceShortcutViewController,
        didUpdate voiceShortcut: INVoiceShortcut?,
        error: Error?
    ) {
        controller.dismiss(animated: true, completion: nil)
    }

    public func editVoiceShortcutViewController(
        _ controller: INUIEditVoiceShortcutViewController,
        didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID
    ) {
        controller.dismiss(animated: true, completion: nil)
    }

    public func editVoiceShortcutViewControllerDidCancel(
        _ controller: INUIEditVoiceShortcutViewController
    ) {
        controller.dismiss(animated: true, completion: nil)
    }
}

@available(iOS 13.0, *)
public final class VoiceShortcutRow: Row<VoiceShortcutCell>, RowType {
    var buttonStyle: INUIAddVoiceShortcutButtonStyle = .automatic

    public required init(tag: String?) {
        super.init(tag: tag)
        displayValueFor = { _ in nil }
        // there's no availability method we can use, but the docs say:
        // > This framework ignores calls from Mac apps built with Mac Catalyst.
        hidden = .isCatalyst
    }
}
