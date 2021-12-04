import Eureka
import PromiseKit
import Shared
import UIKit

class ServerSelectViewController: HAFormViewController, ServerObserver, UIAdaptivePresentationControllerDelegate {
    let result: Promise<AccountRowValue>
    private let resultSeal: Resolver<AccountRowValue>

    enum ServerSelectError: Error, CancellableError {
        case cancelled

        var isCancelled: Bool {
            switch self {
            case .cancelled: return true
            }
        }
    }

    var prompt: String? {
        didSet {
            setupForm()
        }
    }

    var allowAll: Bool = false {
        didSet {
            setupForm()
        }
    }

    override init() {
        (self.result, self.resultSeal) = Promise<AccountRowValue>.pending()
        super.init()

        title = L10n.Settings.ServerSelect.pageTitle
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:))),
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupForm()
        Current.servers.add(observer: self)
    }

    @objc private func cancel(_ sender: UIBarButtonItem) {
        resultSeal.reject(ServerSelectError.cancelled)
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        if let parent = parent as? UINavigationController, parent.viewControllers == [self] {
            parent.presentationController?.delegate = self

            // sheet is a little annoying (even with large detent) with many servers
            if #available(iOS 15, *), Current.servers.all.count <= 4 {
                with(parent.sheetPresentationController) {
                    $0?.detents = [.medium(), .large()]
                }
            }
        }
    }

    func serversDidChange(_ serverManager: ServerManager) {
        UIView.performWithoutAnimation {
            setupForm()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        resultSeal.reject(ServerSelectError.cancelled)
    }

    private func setupForm() {
        form.removeAll()

        if let prompt = prompt, !prompt.isEmpty {
            form +++ InfoLabelRow {
                $0.title = prompt
            }
        }

        var rows = [AccountRowValue]()

        if allowAll {
            rows.append(.all)
        }

        rows.append(contentsOf: Current.servers.all.map { .server($0) })

        form +++ Section(rows.map { value in
            HomeAssistantAccountRow {
                $0.value = value
                $0.onCellSelection { [resultSeal] _, _ in
                    resultSeal.fulfill(value)
                }
            }
        })
    }
}
