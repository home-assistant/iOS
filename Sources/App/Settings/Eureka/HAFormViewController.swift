import Eureka
import UIKit

class HAFormViewController: FormViewController {
    init() {
        if UIScreen.main.traitCollection.userInterfaceIdiom == .mac {
            super.init(style: .grouped)
        } else {
            super.init(style: .insetGrouped)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.keyboardDismissMode = .interactive
    }

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // don't end editing automatically
    }
}
