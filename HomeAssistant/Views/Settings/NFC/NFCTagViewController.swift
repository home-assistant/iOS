import Foundation
import Eureka
import Shared
import Iconic

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

        func image(for icon: MaterialDesignIcons) -> UIImage {
            icon.image(ofSize: CGSize(width: 28, height: 28), color: nil)
                .withRenderingMode(.alwaysTemplate)
        }

        form +++ Section(L10n.Nfc.Detail.tagValue)
        <<< LabelRow {
            $0.cellStyle = .default
            $0.title = identifier
            $0.cellSetup { cell, _ in
                cell.textLabel?.font = UIFont.monospacedSystemFont(ofSize: 19.0, weight: .medium)
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.lineBreakMode = .byCharWrapping
            }
        }
        <<< ButtonRow {
            $0.title = L10n.Nfc.Detail.copy
            $0.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .natural
                cell.imageView?.image = image(for: .contentCopyIcon)
            }
            $0.onCellSelection { [identifier] _, _ in
                UIPasteboard.general.string = identifier
            }
        }
        <<< ButtonRow {
            $0.title = L10n.Nfc.Detail.share
            $0.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .natural
                // mdi icon is rotated?
                cell.imageView?.transform = .init(rotationAngle: -CGFloat.pi / 2.0)
                cell.imageView?.image = image(for: .exportIcon)
            }
            $0.onCellSelection { [weak self, identifier] cell, _ in
                let controller = UIActivityViewController(activityItems: [ identifier ], applicationActivities: [])
                controller.popoverPresentationController?.sourceView = cell
                controller.popoverPresentationController?.sourceRect = cell.bounds
                self?.present(controller, animated: true, completion: nil)
            }
        }

        form +++ Section()
        <<< ButtonRow {
            $0.title = L10n.Nfc.Detail.duplicate
            $0.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .natural
                cell.imageView?.image = image(for: .nfcTapIcon)
            }
            $0.onCellSelection { [identifier] _, _ in
                Current.Log.info("duplicating \(identifier)")
                Current.nfc.write(value: identifier).cauterize()
            }
        }
        <<< ButtonRow {
            $0.title = L10n.Nfc.Detail.fire
            $0.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .natural
                cell.imageView?.image = image(for: .bellRingOutlineIcon)
            }
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
