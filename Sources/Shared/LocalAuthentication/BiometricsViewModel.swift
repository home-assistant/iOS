//
//  BiometricsViewModel.swift
//  Shared-iOS
//
//  Created by Bruno Pantaleão on 05/12/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation

public protocol BiometricsViewModelDelegate: AnyObject {
    func didRequestUnlock()
}

@available(iOS 13.0, *)
final class BiometricsViewModel: ObservableObject {

    weak var delegate: BiometricsViewModelDelegate?

    func unlock() {
        delegate?.didRequestUnlock()
    }
}
