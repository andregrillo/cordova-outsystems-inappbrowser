//
//  OSIABWebViewModelManager.swift
//  InAppBrowser WebViewModel Manager
//

import Foundation

/// Singleton manager to keep track of the current WebViewModel for script injection
final class OSIABWebViewModelManager {
    static let shared = OSIABWebViewModelManager()
    private init() {}

    private var currentModel: OSIABWebViewModel?

    func set(model: OSIABWebViewModel) {
        self.currentModel = model
    }

    func get() -> OSIABWebViewModel? {
        return currentModel
    }

    func clear() {
        self.currentModel = nil
    }
}
