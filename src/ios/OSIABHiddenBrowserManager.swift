import Foundation
import WebKit

/// Manager for hidden InAppBrowser instances used for background authentication flows
class OSIABHiddenBrowserManager: NSObject {
    static let shared = OSIABHiddenBrowserManager()

    private var hiddenBrowsers: [String: HiddenBrowserInstance] = [:]

    private override init() {
        super.init()
    }

    class HiddenBrowserInstance: NSObject, WKNavigationDelegate {
        let webView: WKWebView
        let browserId: String
        var timer: Timer?
        let completionHandler: (OSIABEventType, Any?) -> Void
        private var firstLoadDone = false
        private let originalUrl: URL
        private var navigationCompletedTimer: DispatchWorkItem?
        private let navigationCompletedDelay: TimeInterval

        init(browserId: String, url: URL, options: OSIABWebViewOptions, customHeaders: [String: String]?, timeout: Int?, completionHandler: @escaping (OSIABEventType, Any?) -> Void) {
            self.browserId = browserId
            self.originalUrl = url
            self.navigationCompletedDelay = TimeInterval(options.navigationCompletedDelayMs) / 1000.0
            self.completionHandler = completionHandler

            // Create WKWebView configuration
            let configuration = WKWebViewConfiguration()
            configuration.allowsInlineMediaPlayback = options.allowInLineMediaPlayback
            configuration.mediaTypesRequiringUserActionForPlayback = options.mediaTypesRequiringUserActionForPlayback
            configuration.suppressesIncrementalRendering = options.surpressIncrementalRendering

            // Create a 1x1 hidden webview
            self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)

            super.init()

            // Configure WebView
            self.webView.navigationDelegate = self
            if let userAgent = options.customUserAgent {
                self.webView.customUserAgent = userAgent
            }

            // Clear cache if needed
            if options.clearCache {
                WKWebsiteDataStore.default().removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    modifiedSince: Date(timeIntervalSince1970: 0),
                    completionHandler: {}
                )
            } else if options.clearSessionCache {
                WKWebsiteDataStore.default().removeData(
                    ofTypes: Set([WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage]),
                    modifiedSince: Date(timeIntervalSince1970: 0),
                    completionHandler: {}
                )
            }

            // Load URL with custom headers if provided
            var request = URLRequest(url: url)
            if let headers = customHeaders {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            self.webView.load(request)

            // Set up timeout if specified
            if let timeout = timeout, timeout > 0 {
                self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeout), repeats: false) { [weak self] _ in
                    self?.completionHandler(.pageClosed, ["reason": "timeout"])
                }
            }
        }

        // WKNavigationDelegate methods
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Cancel any pending navigation completed events since a new navigation is starting
            navigationCompletedTimer?.cancel()
            navigationCompletedTimer = nil
            decisionHandler(.allow)
        }

        /// Helper function to extract the domain (host) from a URL
        private func extractDomain(from url: URL?) -> String? {
            return url?.host
        }

        /// Helper function to check if a URL matches the original domain
        private func matchesOriginalDomain(_ url: URL?) -> Bool {
            guard let originalHost = extractDomain(from: originalUrl),
                  let currentHost = extractDomain(from: url) else {
                return false
            }
            return originalHost == currentHost
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Only fire pageLoadCompleted when we return to the original domain after potential SSO redirects
            if !firstLoadDone && matchesOriginalDomain(webView.url) {
                firstLoadDone = true
                completionHandler(.pageLoadCompleted, nil)
            } else {
                // Debounce the navigation completed event to handle redirect chains
                // Cancel any pending event first
                navigationCompletedTimer?.cancel()

                // Schedule new event to fire after delay (configurable)
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.completionHandler(.pageNavigationCompleted, self.webView.url?.absoluteString)
                    self.navigationCompletedTimer = nil
                }
                navigationCompletedTimer = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + navigationCompletedDelay, execute: workItem)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            completionHandler(.pageClosed, ["error": error.localizedDescription])
        }

        func cleanup() {
            timer?.invalidate()
            timer = nil
            navigationCompletedTimer?.cancel()
            navigationCompletedTimer = nil
            webView.stopLoading()
            webView.navigationDelegate = nil
        }

        deinit {
            cleanup()
        }
    }

    /// Creates and stores a hidden browser instance
    func create(browserId: String, url: URL, options: OSIABWebViewOptions, customHeaders: [String: String]?, timeout: Int?, completionHandler: @escaping (OSIABEventType, Any?) -> Void) {
        let instance = HiddenBrowserInstance(
            browserId: browserId,
            url: url,
            options: options,
            customHeaders: customHeaders,
            timeout: timeout,
            completionHandler: completionHandler
        )

        hiddenBrowsers[browserId] = instance
    }

    /// Removes a hidden browser instance
    func remove(browserId: String) {
        guard let instance = hiddenBrowsers[browserId] else { return }
        instance.cleanup()
        hiddenBrowsers.removeValue(forKey: browserId)
    }

    /// Gets a hidden browser instance
    func get(browserId: String) -> HiddenBrowserInstance? {
        return hiddenBrowsers[browserId]
    }

    /// Removes all hidden browsers
    func removeAll() {
        for (browserId, _) in hiddenBrowsers {
            remove(browserId: browserId)
        }
    }
}
