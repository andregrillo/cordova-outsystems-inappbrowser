# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Cordova plugin for OutSystems customers that provides InAppBrowser functionality for iOS and Android mobile applications. The plugin allows opening web content in:
- External browser (separate app)
- System browser (SafariViewController on iOS, CustomTabs on Android)
- Custom WebView (in-app browser with customization options)
- Hidden browser (background authentication flows)

## Build Commands

```bash
# Build the JavaScript bridge layer (TypeScript → JavaScript)
npm run build

# Update version tags and deploy
npm run update:version  # Tag O11 applications
npm run update:tag      # Change extensibility tags
npm run deploy          # Deploy plugin
npm run download        # Download plugin artifacts
```

**Build output**: Compiles `src/www/index.ts` to `dist/plugin.js` (UMD, ESM, CJS formats) using Vite.

**No test suite**: This project does not have automated tests. Testing is done manually with Cordova test apps.

## Architecture Overview

### JavaScript Bridge Layer (Cordova exec)

The plugin uses Cordova's `exec()` bridge pattern to communicate between JavaScript and native code:

```
JavaScript (src/www/web.ts)
    ↓ exec()
Native Plugin Entry (OSInAppBrowser.kt / OSInAppBrowser.swift)
    ↓ delegates to
Router Pattern (OSIABEngine → OSIABRouter implementations)
    ↓ emits events
Callbacks back to JavaScript
```

**Key files**:
- `src/www/web.ts` - Bridge implementation using `cordova.exec()`
- `src/www/definitions.ts` - TypeScript interfaces and enums
- `src/www/defaults.ts` - Default option values per platform

**Event flow**: Native events are serialized as JSON with numeric event types (`CallbackEventType` enum: 1=SUCCESS, 2=PAGE_CLOSED, 3=PAGE_LOAD_COMPLETED, 4=PAGE_NAVIGATION_COMPLETED) and sent back through persistent callbacks (`keepCallback: true`).

### Native Code Structure

Both platforms follow a similar **Router Pattern** architecture:

```
Plugin Entry Point (CordovaPlugin/CDVPlugin)
    → OSIABEngine (orchestrator)
        → OSIABRouter implementations:
            - ExternalBrowserRouterAdapter
            - SystemBrowserRouterAdapter (CustomTabs/SafariViewController)
            - WebViewRouterAdapter (custom WebView with UI controls)
```

**Android** (`src/android/`):
- Language: Kotlin
- Event bus: Kotlin Flow (`MutableSharedFlow`) for event emission
- View architecture: Activity-based (imperative)
- Key classes:
  - `OSInAppBrowser.kt` - Main plugin entry point
  - `lib/OSIABEngine.kt` - Router orchestrator
  - `lib/OSIABEvents.kt` - Sealed classes for type-safe events
  - `lib/views/OSIABWebViewActivity.kt` - WebView UI Activity
  - `OSIABWebViewManager.kt` - Static manager for active WebView instance
  - `OSIABHiddenBrowserManager.kt` - Manages hidden browser instances

**iOS** (`src/ios/`):
- Language: Swift
- Event bus: Closures/completion handlers
- View architecture: SwiftUI-based (declarative)
- Key classes:
  - `OSInAppBrowser.swift` - Main plugin entry point
  - `lib/OSIABEngine.swift` - Generic router orchestrator
  - `lib/WebView/OSIABWebViewModel.swift` - SwiftUI ViewModel with WKWebView
  - `OSIABWebViewModelManager.swift` - Manager for active WebView
  - `OSIABHiddenBrowserManager.swift` - Manages hidden browser instances

### Hidden Browser Pattern

Hidden browsers run in the background without UI, useful for authentication flows:

- Returns `browserId` immediately via success callback
- Emits events asynchronously (PAGE_LOADED, NAVIGATION_COMPLETED, CLOSED)
- Multiple concurrent hidden browsers are supported (managed in dictionary/map)
- Separate from visible browser (different manager)

**JavaScript API**:
```javascript
openHidden(url, options, success, error, browserCallbacks)
closeHidden(browserId, success, error)
```

### CSS/JS Injection

The plugin supports injecting CSS and JavaScript into the currently active WebView:

```javascript
insertCSS(code, success, error)
executeScript(code, success, error)
```

These methods access the WebView via static managers (`OSIABWebViewManager` / `OSIABWebViewModelManager`).

## Navigation Completed Debouncing (Critical Pattern)

**Problem**: In redirect chains (e.g., SSO flows: App → Login → App), the `BrowserPageNavigationCompleted` event was firing on every intermediate page, causing `insertCSS` and `executeScript` to fail because pages were navigating away.

**Solution**: 300ms debounce timer that waits for page stabilization before firing the event.

**Implementation**:
- **Android** (`OSIABWebViewActivity.kt:407-473`, `OSIABHiddenBrowserManager.kt:35-127`):
  - Uses `Handler.postDelayed()` with `Runnable`
  - Timer cancelled in `onPageStarted`, scheduled in `onPageFinished`

- **iOS** (`OSIABWebViewModel.swift:23-236`, `OSIABHiddenBrowserManager.swift:20-115`):
  - Uses `DispatchQueue.asyncAfter()` with `DispatchWorkItem`
  - Timer cancelled in `decidePolicyFor navigationAction`, scheduled in `didFinish navigation`

**Testing**: Test with SSO flows or multi-redirect URLs to ensure event fires once after all redirects complete.

## OutSystems Service Studio Integration

The plugin is designed for OutSystems' low-code platform (Service Studio):

1. **Null value handling**: Service Studio may send `"<null>"` strings instead of actual nulls. iOS implementation has special handling in `cleanNullValues()`.

2. **Numeric event types**: Uses numeric enum values (not strings) for `CallbackEventType` to ensure compatibility with Service Studio's type system.

3. **Error codes**: Standardized error codes (OS-PLUG-IABP-0005 through OS-PLUG-IABP-0012) documented in README.

4. **Options transformation**: Three-tier pattern to handle Service Studio's data model:
   - TypeScript interfaces → GSON/Codable models → Native data classes

## Plugin Configuration (plugin.xml)

- **Plugin ID**: `com.outsystems.plugins.inappbrowser`
- **Platforms**: Android (minSdkVersion 24), iOS (deployment target 13.0)
- **Hooks**:
  - `before_plugin_install`: Handle Android cleartext traffic configuration
  - `after_plugin_install` & `after_prepare`: Update Android R imports
- **Native registration**:
  - Android: `<feature name="OSInAppBrowser">` registers Kotlin class
  - iOS: `<feature name="OSInAppBrowser">` registers Swift class

## Public API

See README.md for full API documentation. Summary:

- `openInExternalBrowser(url, success, error)` - Opens in separate browser app
- `openInSystemBrowser(url, options, success, error, browserCallbacks)` - SafariViewController/CustomTabs
- `openInWebView(url, options, success, error, browserCallbacks)` - Custom WebView with UI controls
- `close(success, error)` - Closes active visible browser
- `insertCSS(code, success, error)` - Inject CSS into current page
- `executeScript(code, success, error)` - Execute JavaScript in current page
- `openHidden(url, options, success, error, browserCallbacks)` - Background browser
- `closeHidden(browserId, success, error)` - Close specific hidden browser

**Callbacks**:
- `onbrowserClosed` - Browser dismissed by user
- `onbrowserPageLoaded` - Page finished loading
- `onbrowserPageNavigationCompleted` - Navigation stabilized (after debounce)

## Development Patterns

### Memory Management
- **Android**: Use `WeakReference<T>` for Activity references to prevent leaks
- **iOS**: Use `[weak self]` in closures

### Persistent Callbacks
Set `keepCallback = true` on `PluginResult` to receive multiple events from the same callback context.

### Platform-Specific Options
Options structures have platform-specific nested objects (`android`, `iOS`) to handle differences in capabilities and styling.

## Recent Changes

See git history for details. Notable recent fixes:
- Fixed SSO redirect handling in BrowserPageLoaded and NavigationCompleted events (commit f5253ed)
- Fixed BrowserPageNavigationCompleted event debouncing (commit bcae453)
- Fixed onbrowserClosed event for iOS and Android (commits f5fe4e6, 49d923b, 5c52f4a)
