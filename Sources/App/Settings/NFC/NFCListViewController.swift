import CoreNFC
import Eureka
import Foundation
import PromiseKit
import Shared
import PMKFoundation

class NFCListViewController: HAFormViewController {
    override init() {
        super.init()

        title = L10n.Nfc.List.title
    }

    private var lastManualIdentifier: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        form +++ Section()
            <<< InfoLabelRow {
                $0.title = L10n.Nfc.List.description
                $0.displayType = .primary
            }

            <<< LearnMoreButtonRow {
                $0.value = URL(string: "https://companion.home-assistant.io/app/ios/nfc")!
            }

        if Current.tags.isNFCAvailable {
            func image(for icon: MaterialDesignIcons) -> UIImage {
                icon.image(
                    ofSize: .init(width: 32, height: 32),
                    color: nil
                ).withRenderingMode(.alwaysTemplate)
            }

            form +++ Section()
                <<< ButtonRow {
                    $0.title = L10n.Nfc.List.readTag
                    $0.cellSetup { cell, _ in
                        cell.imageView?.image = image(for: .nfcVariantIcon)
                    }
                    $0.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .natural
                    }
                    $0.onCellSelection { [weak self] cell, _ in
                        self?.read(sender: cell)
                    }
                }
                <<< ButtonRow {
                    $0.title = L10n.Nfc.List.writeTag
                    $0.cellSetup { cell, _ in
                        cell.imageView?.image = image(for: .nfcTapIcon)
                    }
                    $0.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .natural
                    }
                    $0.onCellSelection { [weak self] cell, _ in
                        self?.write(sender: cell)
                    }
                }
        } else {
            form +++ LabelRow {
                $0.title = L10n.Nfc.notAvailable
            }
        }
    }

    private func perform(with promise: Promise<String>) {
        firstly {
            promise
        }.done { [navigationController] value in
            Current.Log.info("NFC tag with value \(value)")
            let controller = NFCTagViewController(identifier: value)
            navigationController?.pushViewController(controller, animated: true)
        }.catch { [weak self] error in
            Current.Log.error(error)

            if error is TagManagerError {
                let alert = UIAlertController(
                    title: error.localizedDescription,
                    message: nil,
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }

    private func read(sender: UIView) {
        perform(with: Current.tags.readNFC())
    }

    private func write(sender: UIView) {
        let sheet = UIAlertController(
            title: L10n.Nfc.Write.IdentifierChoice.title,
            message: L10n.Nfc.Write.IdentifierChoice.message,
            preferredStyle: .actionSheet
        )

        with(sheet.popoverPresentationController) {
            $0?.sourceView = sender
            $0?.sourceRect = sender.bounds
        }

        sheet.addAction(UIAlertAction(title: L10n.Nfc.Write.IdentifierChoice.random, style: .default, handler: { _ in
            self.perform(with: Current.tags.writeRandomNFC())
        }))

        sheet.addAction(UIAlertAction(title: L10n.Nfc.Write.IdentifierChoice.manual, style: .default, handler: { _ in
            self.perform(with: self.writeWithManual())
        }))

        sheet.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }

    private func writeWithManual() -> Promise<String> {
        let (promise, seal) = Promise<String>.pending()

        let question = UIAlertController(
            title: L10n.Nfc.Write.ManualInput.title,
            message: nil,
            preferredStyle: .alert
        )

        let doneAction = UIAlertAction(title: L10n.doneLabel, style: .default, handler: { _ in
            if let text = question.textFields?.first?.text, text.isEmpty == false {
                self.lastManualIdentifier = text
                Current.tags.writeNFC(value: text).pipe(to: seal.resolve)
            } else {
                seal.reject(PMKError.cancelled)
            }
        })

        question.addAction(doneAction)
        question.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: { _ in
            seal.reject(PMKError.cancelled)
        }))

        question.addTextField { textField in
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.keyboardType = .default
            textField.text = self.lastManualIdentifier
            textField.enablesReturnKeyAutomatically = true

            func updateDoneAction() {
                if let text = textField.text, !text.isEmpty {
                    doneAction.isEnabled = true
                } else {
                    doneAction.isEnabled = false
                }
            }

            var token: NSObjectProtocol? = NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification,
                object: textField,
                queue: nil
            ) { _ in
                updateDoneAction()
            }

            after(life: textField).done {
                if let token {
                    NotificationCenter.default.removeObserver(token)
                }
                token = nil
            }

            updateDoneAction()
        }

        present(question, animated: true, completion: nil)

        return promise
    }
}
