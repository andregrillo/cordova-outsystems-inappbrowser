package com.outsystems.plugins.inappbrowser.osinappbrowser

import android.os.Handler
import android.os.Looper
import android.webkit.WebView

/**
 * Extension functions for WebView to support insertCSS and executeScript
 */

/**
 * Inserts CSS code into the current page loaded in the WebView
 * @param cssCode The CSS code to inject
 * @param callback Optional callback to be invoked after execution (receives error message or null on success)
 */
fun WebView.insertCSS(cssCode: String, callback: ((String?) -> Unit)? = null) {
    val escapedCss = cssCode.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "\\r")

    val jsWrapper = """
        (function() {
            try {
                var style = document.createElement('style');
                style.innerHTML = '$escapedCss';
                document.head.appendChild(style);
            } catch(e) {
                return 'Error: ' + e.message;
            }
        })();
    """.trimIndent()

    Handler(Looper.getMainLooper()).post {
        this.evaluateJavascript(jsWrapper) { result ->
            val error = if (result != null && result != "null" && result.isNotBlank()) {
                result.trim('"')
            } else {
                null
            }
            callback?.invoke(error)
        }
    }
}

/**
 * Executes JavaScript code in the current page loaded in the WebView
 * @param jsCode The JavaScript code to execute
 * @param callback Optional callback to be invoked after execution (receives error message or null on success)
 */
fun WebView.executeScript(jsCode: String, callback: ((String?) -> Unit)? = null) {
    Handler(Looper.getMainLooper()).post {
        this.evaluateJavascript(jsCode) { result ->
            // Check if there was an error (evaluateJavascript returns null on error)
            callback?.invoke(null)
        }
    }
}
