//
//  ClientEventsLogViewModel.swift
//  App
//
//  Created by Bruno Pantaleão on 28/11/24.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Shared

final class ClientEventsLogViewModel: ObservableObject {
    @Published var events: [ClientEvent] = []
    @Published var isLoading = false
    @Published var searchTerm: String = ""

    func fetchEvents() {
        isLoading = true
        Current.clientEventStore.getEvents(filter: searchTerm) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let events):
                    self?.events = events
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
}
