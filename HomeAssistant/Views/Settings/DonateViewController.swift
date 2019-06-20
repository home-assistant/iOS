//
//  DonateViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 6/18/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import StoreKit
import Eureka
import SwiftConfettiView
import SwiftyStoreKit
import Shared

class DonateViewController: FormViewController {

    var confettiView: SwiftConfettiView!

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L10n.About.Donate.title

        confettiView = SwiftConfettiView(frame: UIScreen.main.bounds)
        confettiView.type = .confetti
        confettiView.isUserInteractionEnabled = false
        UIApplication.shared.keyWindow?.addSubview(confettiView)

        self.form
            +++ Section { section in
                    section.header = {
                        var header = HeaderFooterView<UIView>(.callback({
                            let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
                            let label = UILabel(frame: view.bounds)
                            label.text = L10n.About.Donate.description
                            label.numberOfLines = 0
                            label.font = .preferredFont(forTextStyle: .subheadline)
                            label.textAlignment = .center
                            /* view.layer.borderColor = UIColor.red.cgColor
                            view.layer.borderWidth = 3 */
                            view.addSubview(label)
                            view.sizeToFit()
                            return view
                        }))
                        header.height = { 100 }
                        return header
                    }()
                }

            +++ ButtonRow {
                    $0.title = L10n.About.Donate.patreon
                }.onCellSelection { _, _  in
                    let urlStr = "https://patreon.com/robbiet480/"
                    openURLInBrowser(urlToOpen: URL(string: urlStr)!)
                }

        let oneOffProductIDs: Set<String> = [
            "\(Constants.BundleID).Massive",
            "\(Constants.BundleID).Huge",
            "\(Constants.BundleID).Large",
            "\(Constants.BundleID).Medium",
            "\(Constants.BundleID).Small"
        ]

        let recurringProductIDs: Set<String> = [
            "\(Constants.BundleID).Monthly",
            "\(Constants.BundleID).Yearly"
        ]

        let allProductIDs = oneOffProductIDs.union(recurringProductIDs)

        let oneOffSection = Section(L10n.About.Donate.OneTimeIapSection.title)

        let recurringSection = Section(L10n.About.Donate.RecurringIapSection.title)

        SwiftyStoreKit.retrieveProductsInfo(allProductIDs) { results in

            for product in results.retrievedProducts {
                let row = self.mapProductToRow(product)
                if oneOffProductIDs.contains(product.productIdentifier) {
                    oneOffSection <<< row
                } else if recurringProductIDs.contains(product.productIdentifier) {
                    recurringSection <<< row
                }
            }

            self.form
                +++ recurringSection
                +++ oneOffSection
        }
    }

    func mapProductToRow(_ product: SKProduct) -> ButtonRow {
        return ButtonRow(product.productIdentifier) {
            $0.title = product.localizedTitle
            $0.cellStyle = .subtitle
        }.cellUpdate { cell, _ in
            cell.textLabel?.textAlignment = .left
            cell.detailTextLabel?.text = product.localizedDescription
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
            label.text = product.localizedPrice
            label.textColor = .blue
            label.sizeToFit()
            cell.accessoryView = label
        }.onCellSelection { _, _ in
            self.purchase(product.productIdentifier)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func purchase(_ productID: String) {
        SwiftyStoreKit.purchaseProduct(productID, quantity: 1, atomically: true) { result in
            switch result {
            case .success(let purchase):
                print("Purchase Success: \(purchase.productId)")
                self.confettiView.startConfetti()
            case .error(let error):
                print("Received error", error, error.errorCode, error.errorUserInfo, error.userInfo)
                switch error.code {
                case .unknown: print("Unknown error. Please contact support")
                case .clientInvalid: print("Not allowed to make the payment")
                case .paymentCancelled: break
                case .paymentInvalid: print("The purchase identifier was invalid")
                case .paymentNotAllowed: print("The device is not allowed to make the payment")
                case .storeProductNotAvailable: print("The product is not available in the current storefront")
                case .cloudServicePermissionDenied: print("Access to cloud service information is not allowed")
                case .cloudServiceNetworkConnectionFailed: print("Could not connect to the network")
                case .cloudServiceRevoked: print("User has revoked permission to use this cloud service")
                default: print((error as NSError).localizedDescription)
                }
            }
        }
    }
}
