package com.outsystems.plugins.inappbrowser.osinappbrowser

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import com.outsystems.plugins.inappbrowser.osinappbrowserlib.models.OSIABWebViewOptions
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Manager for hidden InAppBrowser instances used for background authentication flows
 */
object OSIABHiddenBrowserManager {
    private val hiddenBrowsers = ConcurrentHashMap<String, HiddenBrowserInstance>()

    /**
     * Hidden browser instance that runs in the background
     */
    class HiddenBrowserInstance(
        val browserId: String,
        context: Context,
        url: String,
        options: OSIABWebViewOptions,
        customHeaders: Map<String, String>?,
        timeout: Int?,
        val completionHandler: (OSIABEventType, Any?) -> Unit
    ) {
        private val webView: WebView
        private val handler = Handler(Looper.getMainLooper())
        private var timeoutRunnable: Runnable? = null
        private var navigationCompletedRunnable: Runnable? = null
        private var firstLoadDone = false
        private val NAVIGATION_COMPLETED_DELAY_MS = 300L

        init {
            webView = WebView(context).apply {
                // Configure WebView with options
                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    databaseEnabled = true
                    mediaPlaybackRequiresUserGesture = options.mediaPlaybackRequiresUserAction
                    allowFileAccess = true
                    allowContentAccess = true

                    // Set custom user agent if provided
                    options.customUserAgent?.let { userAgentString = it }
                }

                // Clear cache if needed
                if (options.clearCache) {
                    clearCache(true)
                    clearFormData()
                    clearHistory()
                }
                if (options.clearSessionCache) {
                    clearCache(false)
                }

                // Set WebViewClient to handle page events
                webViewClient = object : WebViewClient() {
                    override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                        super.onPageStarted(view, url, favicon)
                        // Cancel any pending navigation completed events since a new navigation has started
                        navigationCompletedRunnable?.let { handler.removeCallbacks(it) }
                        navigationCompletedRunnable = null
                    }

                    override fun onPageFinished(view: WebView?, url: String?) {
                        if (!firstLoadDone) {
                            firstLoadDone = true
                            completionHandler(OSIABEventType.BROWSER_PAGE_LOADED, null)
                        } else {
                            // Debounce the navigation completed event to handle redirect chains
                            // Cancel any pending event first
                            navigationCompletedRunnable?.let { handler.removeCallbacks(it) }

                            // Schedule new event to fire after delay
                            navigationCompletedRunnable = Runnable {
                                completionHandler(OSIABEventType.BROWSER_PAGE_NAVIGATION_COMPLETED, url)
                                navigationCompletedRunnable = null
                            }
                            handler.postDelayed(navigationCompletedRunnable!!, NAVIGATION_COMPLETED_DELAY_MS)
                        }
                    }

                    override fun onReceivedError(
                        view: WebView?,
                        request: WebResourceRequest?,
                        error: WebResourceError?
                    ) {
                        super.onReceivedError(view, request, error)
                        val errorData = mapOf("error" to (error?.description?.toString() ?: "Unknown error"))
                        completionHandler(OSIABEventType.BROWSER_FINISHED, errorData)
                    }
                }

                // Load URL with custom headers if provided
                if (customHeaders != null && customHeaders.isNotEmpty()) {
                    loadUrl(url, customHeaders)
                } else {
                    loadUrl(url)
                }
            }

            // Set up timeout if specified
            timeout?.let { timeoutSeconds ->
                if (timeoutSeconds > 0) {
                    timeoutRunnable = Runnable {
                        val timeoutData = mapOf("reason" to "timeout")
                        completionHandler(OSIABEventType.BROWSER_FINISHED, timeoutData)
                    }
                    handler.postDelayed(timeoutRunnable!!, (timeoutSeconds * 1000).toLong())
                }
            }
        }

        fun cleanup() {
            timeoutRunnable?.let { handler.removeCallbacks(it) }
            navigationCompletedRunnable?.let { handler.removeCallbacks(it) }
            webView.stopLoading()
            webView.destroy()
        }
    }

    /**
     * Creates and stores a hidden browser instance
     */
    fun create(
        browserId: String,
        context: Context,
        url: String,
        options: OSIABWebViewOptions,
        customHeaders: Map<String, String>?,
        timeout: Int?,
        completionHandler: (OSIABEventType, Any?) -> Unit
    ) {
        val instance = HiddenBrowserInstance(
            browserId,
            context,
            url,
            options,
            customHeaders,
            timeout,
            completionHandler
        )
        hiddenBrowsers[browserId] = instance
    }

    /**
     * Removes a hidden browser instance
     */
    fun remove(browserId: String) {
        hiddenBrowsers[browserId]?.let { instance ->
            instance.cleanup()
            hiddenBrowsers.remove(browserId)
        }
    }

    /**
     * Gets a hidden browser instance
     */
    fun get(browserId: String): HiddenBrowserInstance? {
        return hiddenBrowsers[browserId]
    }

    /**
     * Removes all hidden browsers
     */
    fun removeAll() {
        hiddenBrowsers.keys.forEach { browserId ->
            remove(browserId)
        }
    }
}
