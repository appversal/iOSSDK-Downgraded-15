//
//  MilestoneViewModel.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/12/25.
//

import SwiftUI
import Combine

// MARK: - View Model
@MainActor
class MilestoneViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var currentProgressValue: Double = 0
    
    let details: MilestoneDetails
    private var cancellables = Set<AnyCancellable>()
    
    // Helper to get sorted items to ensure order matches logic everywhere
    var sortedMilestoneItems: [MilestoneItem] {
        details.milestoneItems?.sorted(by: { $0.order < $1.order }) ?? []
    }
    
    // Computed properties for the UI
    var milestoneValues: [Double] {
        return sortedMilestoneItems.compactMap { item in
            item.triggerEvents?.first?.progressLogic?.value
        }
    }
    
    var stepLabels: [String] {
        return sortedMilestoneItems.map { $0.label ?? "" }
    }
    
    init(details: MilestoneDetails) {
        self.details = details
        self.currentStep = 0
        setupEventObserver()
    }
    
    private func setupEventObserver() {
        AppStorys.shared.$trackedEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                self?.calculateProgress(basedOn: events)
            }
            .store(in: &cancellables)
    }
    
    private func calculateProgress(basedOn trackedEvents: Set<String>) {
        let items = sortedMilestoneItems
        
        var maxCompletedStep = 0
        
        for (index, item) in items.enumerated() {
            if let trigger = item.triggerEvents?.first,
               let eventName = trigger.eventName {
                
                if trackedEvents.contains(eventName) {
                    maxCompletedStep = index + 1
                }
            }
        }
        
        withAnimation {
            self.currentStep = maxCompletedStep
        }
    }
}
