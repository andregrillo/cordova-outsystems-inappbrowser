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

        init(browserId: String, url: URL, options: OSIABWebViewOptions, customHeaders: [String: String]?, timeout: Int?, completionHandler: @escaping (OSIABEventType, Any?) -> Void) {
            self.browserId = browserId
            self.completionHandler = completionHandler

            // Create WKWebView configuration
            let configuration = WKWebViewConfiguration()
            configuration.allowsInlineMediaPlayback = options.allowInLineMediaPlayback
            configuration.mediaTypesRequiringUserActionForPlayback = options.mediaPlaybackRequiresUserAction ? .all : []
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
                let dataStore = WKWebsiteDataStore.default()
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0)) { }
            } else if options.clearSessionCache {
                let dataStore = WKWebsiteDataStore.default()
                let types = Set([WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage])
                dataStore.removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0)) { }
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
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !firstLoadDone {
                firstLoadDone = true
                completionHandler(.pageLoadCompleted, nil)
            } else {
                completionHandler(.pageNavigationCompleted, webView.url?.absoluteString)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            completionHandler(.pageClosed, ["error": error.localizedDescription])
        }

        func cleanup() {
            timer?.invalidate()
            timer = nil
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
