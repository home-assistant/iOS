import Foundation
import Eureka
import Shared

@available(iOS 13, *)
class NFCTagViewController: FormViewController {
    let identifier: String

    init(identifier: String) {
        self.identifier = identifier
        super.init(style: .insetGrouped)

        title = L10n.Nfc.Detail.title
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        form +++ Section(L10n.Nfc.Detail.tagValue)
        <<< LabelRow {
            $0.cellStyle = .default
            $0.title = identifier
            $0.cellSetup { cell, _ in
                let baseSize = UIFont.preferredFont(forTextStyle: .body).pointSize - 2.0
                cell.textLabel?.font = UIFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.lineBreakMode = .byCharWrapping
            }
        }
        <<< ButtonRow {
            $0.title = L10n.Nfc.Detail.duplicate
            $0.onCellSelection { [identifier] _, _ in
                Current.Log.info("duplicating \(identifier)")
                Current.nfc.write(value: identifier).cauterize()
            }
        }
        <<< ButtonRow {
            $0.title = L10n.Nfc.Detail.fire
            $0.onCellSelection { [identifier] _, _ in
                Current.nfc.fireEvent(tag: identifier).cauterize()
            }
        }

        form +++ YamlSection(
            tag: "example-triger",
            header: L10n.Nfc.Detail.exampleTrigger,
            yamlGetter: { [identifier] () -> String in
                let data = HomeAssistantAPI.nfcTagEvent(tagPath: identifier)
                let eventDataStrings = data.eventData.map { $0 + ": " + $1 }.sorted()

                let indentation = "\n    "

                return """
                - platform: event
                  event_type: \(data.eventType)
                  event_data:
                    \(eventDataStrings.joined(separator: indentation))
                """
            }, present: { [weak self] viewController in
                self?.present(viewController, animated: true, completion: nil)
            }
        )
    }
}
