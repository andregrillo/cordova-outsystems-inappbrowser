import { require } from "cordova";
import { BrowserCallbacks, PluginError, SystemBrowserOptions, WebViewOptions, CallbackEvent, CallbackEventType, HiddenBrowserCallbacks, HiddenBrowserData } from "./definitions";
import { DefaultSystemBrowserOptions, DefaultWebViewOptions } from "./defaults";
var exec = require('cordova/exec')

function trigger(type: CallbackEventType, success: () => void, data?: any, onbrowserClosed: (() => void) | undefined = undefined, onbrowserPageLoaded: (() => void) | undefined = undefined, onbrowserPageNavigationCompleted: ((data?: string) => void) | undefined = undefined) {
  switch (type) {
  case CallbackEventType.SUCCESS: 
    success();
    break
  case CallbackEventType.PAGE_CLOSED:
    if (onbrowserClosed) {
      onbrowserClosed();
    }
    break;
  case CallbackEventType.PAGE_LOAD_COMPLETED:
    if (onbrowserPageLoaded) {
      onbrowserPageLoaded();
    }
    break;
  case CallbackEventType.PAGE_NAVIGATION_COMPLETED:
    if (onbrowserPageNavigationCompleted) {
      onbrowserPageNavigationCompleted(data);
    }
    break;
  default: break;
  }
}

function openInWebView(url: string, options: WebViewOptions, success: () => void, error: (error: PluginError) => void, browserCallbacks?: BrowserCallbacks, customHeaders?: { [key: string]: string } | null): void {
  options = options || DefaultWebViewOptions;
  
  let triggerCorrectCallback = function (result: string) {
    const parsedResult: CallbackEvent = JSON.parse(result);
    if (parsedResult) {
      if (browserCallbacks) {
        trigger(parsedResult.eventType, success, parsedResult.data, browserCallbacks.onbrowserClosed, browserCallbacks.onbrowserPageLoaded, browserCallbacks.onbrowserPageNavigationCompleted);
      } else {
        trigger(parsedResult.eventType, success, parsedResult.data);
      }
    }
  };

  exec(triggerCorrectCallback, error, 'OSInAppBrowser', 'openInWebView', [{url, options, customHeaders}]);
}

function openInSystemBrowser(url: string, options: SystemBrowserOptions, success: () => void, error: (error: PluginError) => void, browserCallbacks?: BrowserCallbacks): void {
  options = options || DefaultSystemBrowserOptions;
  
  let triggerCorrectCallback = function (result: string) {
    const parsedResult: CallbackEvent = JSON.parse(result);
    if (parsedResult) {
      if (browserCallbacks) {
        trigger(parsedResult.eventType, success, parsedResult.data, browserCallbacks.onbrowserClosed, browserCallbacks.onbrowserPageLoaded);
      } else {
        trigger(parsedResult.eventType, success);
      }
    }
  };

  exec(triggerCorrectCallback, error, 'OSInAppBrowser', 'openInSystemBrowser', [{url, options}]);
}

function openInExternalBrowser(url: string, success: () => void, error: (error: PluginError) => void): void {
  exec(success, error, 'OSInAppBrowser', 'openInExternalBrowser', [{url}])
}

function close(success: () => void, error: (error: PluginError) => void): void {
  exec(success, error, 'OSInAppBrowser', 'close', [{}])
}

function insertCSS(cssCode: string, success: () => void, error: (error: PluginError) => void): void {
  exec(success, error, 'OSInAppBrowser', 'insertCSS', [cssCode])
}

function executeScript(jsCode: string, success: () => void, error: (error: PluginError) => void): void {
  exec(success, error, 'OSInAppBrowser', 'executeScript', [jsCode])
}

function openHidden(url: string, options: WebViewOptions, success: (browserId: string) => void, error: (error: PluginError) => void, browserCallbacks?: HiddenBrowserCallbacks, customHeaders?: { [key: string]: string } | null): void {
  options = options || DefaultWebViewOptions;

  let triggerCorrectCallback = function (result: string) {
    console.log('[OSInAppBrowser] openHidden callback received:', result);
    const parsedResult: CallbackEvent = JSON.parse(result);
    console.log('[OSInAppBrowser] Parsed result:', parsedResult);
    if (parsedResult) {
      const hiddenData = parsedResult.data as HiddenBrowserData;

      if (parsedResult.eventType === CallbackEventType.SUCCESS) {
        console.log('[OSInAppBrowser] SUCCESS event, calling success callback with browserId:', hiddenData.browserId);
        success(hiddenData.browserId);
      } else if (browserCallbacks) {
        console.log('[OSInAppBrowser] Event type:', parsedResult.eventType, 'browserCallbacks exists:', !!browserCallbacks);
        switch (parsedResult.eventType) {
          case CallbackEventType.PAGE_CLOSED:
            console.log('[OSInAppBrowser] Calling onbrowserClosed with browserId:', hiddenData.browserId);
            browserCallbacks.onbrowserClosed(hiddenData.browserId);
            break;
          case CallbackEventType.PAGE_LOAD_COMPLETED:
            console.log('[OSInAppBrowser] Calling onbrowserPageLoaded with browserId:', hiddenData.browserId);
            browserCallbacks.onbrowserPageLoaded(hiddenData.browserId);
            break;
          case CallbackEventType.PAGE_NAVIGATION_COMPLETED:
            console.log('[OSInAppBrowser] Calling onbrowserPageNavigationCompleted with browserId:', hiddenData.browserId);
            browserCallbacks.onbrowserPageNavigationCompleted(hiddenData.browserId, hiddenData.data);
            break;
        }
      } else {
        console.log('[OSInAppBrowser] No browserCallbacks registered for event type:', parsedResult.eventType);
      }
    }
  };

  exec(triggerCorrectCallback, error, 'OSInAppBrowser', 'openHidden', [{url, options, customHeaders}]);
}

function closeHidden(browserId: string, success: () => void, error: (error: PluginError) => void): void {
  exec(success, error, 'OSInAppBrowser', 'closeHidden', [browserId])
}

module.exports = {
  openInWebView,
  openInExternalBrowser,
  openInSystemBrowser,
  close,
  insertCSS,
  executeScript,
  openHidden,
  closeHidden
}
