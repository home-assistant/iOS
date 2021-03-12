import Eureka
import Foundation
import HAKit
import Shared

class TemplateEditViewController: FormViewController, RowControllerType {
    var onDismissCallback: ((UIViewController) -> Void)?
    var saveHandler: (String) -> Void

    private let initialValue: String
    private var templateSection: TemplateSection?

    init(
        initial: String,
        saveHandler: @escaping (String) -> Void
    ) {
        self.saveHandler = saveHandler
        self.initialValue = initial
        super.init(style: .grouped)

        if #available(iOS 13, *) {
            isModalInPresentation = true
        }

        self.title = L10n.Settings.TemplateEdit.title
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        _ = templateSection?.inputRow.cell.textView.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save)),
        ]

        let section = TemplateSection(
            header: nil,
            footer: nil,
            initializeInput: {
                $0.value = initialValue
                $0.placeholder = "{{ now() }}"
            }, initializeSection: { _ in
            }
        )
        form +++ section
        templateSection = section
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc private func save() {
        if let section = templateSection {
            saveHandler(section.inputRow.value ?? "")
        }
        onDismissCallback?(self)
    }
}
