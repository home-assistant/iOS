//
//  MagicItemEditViewModel.swift
//  App
//
//  Created by Bruno Pantaleão on 13/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Shared
import PromiseKit

final class MagicItemEditViewModel: ObservableObject {
    @Published var item: MagicItem
    @Published var info: MagicItem.Info?

    init(item: MagicItem) {
        self.item = item
    }

    func loadMagicInfo() {
        let itemProvider = Current.magicItemProvider()
        itemProvider.loadInformation { [weak self] in
            guard let self else { return }
            self.info = itemProvider.getInfo(for: self.item)
        }
    }
}
