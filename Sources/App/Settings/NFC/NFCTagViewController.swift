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

        form +++ identifierSection()
        form +++ actionsSection()
        form +++ exampleTriggerSection()
    }

    private func buttonRow(icon: MaterialDesignIcons, configure: (ButtonRow) -> Void) -> ButtonRow {
        ButtonRow {
            $0.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .natural

                if icon == .exportIcon {
                    cell.imageView?.transform = .init(rotationAngle: -CGFloat.pi / 2.0)
                } else {
                    cell.imageView?.transform = .identity
                }

                cell.imageView?.image = icon
                    .image(ofSize: CGSize(width: 28, height: 28), color: nil)
                    .withRenderingMode(.alwaysTemplate)
            }

            configure($0)
        }
    }

    private func identifierSection() -> Section {
        return Section(L10n.Nfc.Detail.tagValue)
        <<< LabelRow {
            $0.cellStyle = .default
            $0.title = identifier
            $0.cellSetup { cell, _ in
                cell.textLabel?.font = UIFont.monospacedSystemFont(ofSize: 19.0, weight: .medium)
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.lineBreakMode = .byCharWrapping
            }
        }
        <<< buttonRow(icon: .contentCopyIcon) {
            $0.title = L10n.Nfc.Detail.copy
            $0.onCellSelection { [identifier] _, _ in
                UIPasteboard.general.string = identifier
            }
        }
        <<< buttonRow(icon: .exportIcon) {
            $0.title = L10n.Nfc.Detail.share
            $0.onCellSelection { [weak self, identifier] cell, _ in
                let controller = UIActivityViewController(activityItems: [ identifier ], applicationActivities: [])
                controller.popoverPresentationController?.sourceView = cell
                controller.popoverPresentationController?.sourceRect = cell.bounds
                self?.present(controller, animated: true, completion: nil)
            }
        }
    }

    private func actionsSection() -> Section {
        return Section()
        <<< buttonRow(icon: .nfcTapIcon) {
            $0.title = L10n.Nfc.Detail.duplicate
            $0.onCellSelection { [identifier] _, _ in
                Current.Log.info("duplicating \(identifier)")
                Current.tags.writeNFC(value: identifier).cauterize()
            }
        }
        <<< buttonRow(icon: .bellRingOutlineIcon) {
            $0.title = L10n.Nfc.Detail.fire
            $0.onCellSelection { [identifier] _, _ in
                Current.tags.fireEvent(tag: identifier).cauterize()
            }
        }
    }

    private func exampleTriggerSection() -> Section {
        YamlSection(
            tag: "example-triger",
            header: L10n.Nfc.Detail.exampleTrigger,
            yamlGetter: { [identifier] () -> String in
                if let version = Current.serverVersion(), version < .tagPlatformTrigger {
                    let data = HomeAssistantAPI.tagEvent(tagPath: identifier)
                    let eventDataStrings = data.eventData.map { $0 + ": " + $1 }.sorted()

                    let indentation = "\n    "

                    return """
                    - platform: event
                      event_type: \(data.eventType)
                      event_data:
                        \(eventDataStrings.joined(separator: indentation))
                    """
                } else {
                    return """
                    - platform: tag
                      tag_id: \(identifier)
                    """
                }
            }, present: { [weak self] viewController in
                self?.present(viewController, animated: true, completion: nil)
            }
        )
    }
}
