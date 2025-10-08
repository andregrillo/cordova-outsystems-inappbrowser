import Foundation
import WebKit

/// Manager for hidden InAppBrowser instances used for background authentication flows
class OSIABHiddenBrowserManager {
    static let shared = OSIABHiddenBrowserManager()

    private var hiddenBrowsers: [String: HiddenBrowserInstance] = [:]

    private init() {}

    struct HiddenBrowserInstance {
        let webView: WKWebView
        let viewModel: OSIABWebViewModel
        var timer: Timer?
    }

    /// Creates and stores a hidden browser instance
    func create(browserId: String, url: URL, options: OSIABWebViewOptions, customHeaders: [String: String]?, timeout: Int?, completionHandler: @escaping (OSIABEventType, Any?) -> Void) {
        // Create a hidden WebView with 1x1 size (invisible but functional)
        let config = OSIABWebViewConfigurationModel(
            url: url,
            options: options,
            customHeaders: customHeaders
        )

        let viewModel = OSIABWebViewModel(
            config: config,
            onDelegateClose: { [weak self] in
                self?.remove(browserId: browserId)
                completionHandler(.pageClosed, nil)
            },
            onDelegateURL: { _ in },
            onDelegateAlertController: { _ in },
            completionHandler: { event, data in
                completionHandler(event, data)
            }
        )

        // Create invisible webView
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: viewModel.webViewConfiguration)
        viewModel.setupWebView(webView)
        viewModel.loadURL()

        var instance = HiddenBrowserInstance(webView: webView, viewModel: viewModel, timer: nil)

        // Set up timeout if specified
        if let timeout = timeout, timeout > 0 {
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeout), repeats: false) { [weak self] _ in
                self?.remove(browserId: browserId)
                completionHandler(.pageClosed, ["reason": "timeout"])
            }
            instance.timer = timer
        }

        hiddenBrowsers[browserId] = instance
    }

    /// Removes a hidden browser instance
    func remove(browserId: String) {
        guard let instance = hiddenBrowsers[browserId] else { return }

        instance.timer?.invalidate()
        instance.viewModel.cleanup()
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
