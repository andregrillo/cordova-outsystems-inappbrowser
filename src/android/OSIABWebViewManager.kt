package com.outsystems.plugins.inappbrowser.osinappbrowser

import android.webkit.WebView

/**
 * Singleton manager to keep track of the current WebView for script injection
 */
object OSIABWebViewManager {
    private var currentWebView: WebView? = null

    fun setWebView(webView: WebView) {
        this.currentWebView = webView
    }

    fun getWebView(): WebView? {
        return currentWebView
    }

    fun clear() {
        this.currentWebView = null
    }
}
