//
//  OSIABWebViewModel+ScriptExtensions.swift
//  InAppBrowser Script Injection Extensions
//

import Foundation
import WebKit

/// Extension to OSIABWebViewModel that adds insertCSS and executeScript functionality
extension OSIABWebViewModel {

    /// Inserts CSS code into the current page loaded in the InAppBrowser
    /// - Parameters:
    ///   - code: The CSS code to inject
    ///   - completion: Optional completion handler with success/failure result
    func insertCSS(code: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let jsWrapper = """
        (function() {
            var style = document.createElement('style');
            style.innerHTML = `\(code)`;
            document.head.appendChild(style);
        })();
        """

        self.webView.evaluateJavaScript(jsWrapper) { _, error in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }

    /// Executes JavaScript code in the current page loaded in the InAppBrowser
    /// - Parameters:
    ///   - code: The JavaScript code to execute
    ///   - completion: Optional completion handler with result or error
    func executeScript(code: String, completion: ((Result<Any?, Error>) -> Void)? = nil) {
        self.webView.evaluateJavaScript(code) { result, error in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(result))
            }
        }
    }
}
