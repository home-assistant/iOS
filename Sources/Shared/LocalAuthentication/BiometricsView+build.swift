//
//  BiometricsView+build.swift
//  Shared-iOS
//
//  Created by Bruno Pantaleão on 05/12/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation

@available(iOSApplicationExtension 13.0, *)
extension BiometricsView {
    static func build(delegate: BiometricsViewModelDelegate) -> BiometricsView {
        let viewModel = BiometricsViewModel()
        let view = BiometricsView(viewModel: viewModel)
        viewModel.delegate = delegate
        return view
    }
}
