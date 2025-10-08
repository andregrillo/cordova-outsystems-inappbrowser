package com.outsystems.plugins.inappbrowser.osinappbrowserlib.helpers

import com.outsystems.plugins.inappbrowser.osinappbrowserlib.OSIABEvents
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.transformWhile
import kotlinx.coroutines.launch

class OSIABFlowHelper: OSIABFlowHelperInterface {

    /**
     * Launches a CoroutineScope to collect events from SharedFlow in OSIABEvents.
     * Then, it simply sends the collected event in the onEventReceived callback.
     * @param browserId Identifier for the browser instance to emit events to
     * @param scope CoroutineScope to launch
     * @param onEventReceived callback to send the collected event in
     */
    override fun listenToEvents(
        browserId: String,
        scope: CoroutineScope,
        onEventReceived: (OSIABEvents) -> Unit
    ): Job {
        return scope.launch {
            OSIABEvents.events.transformWhile {
                if (browserId == it.browserId) {
                    emit(it)
                    it !is OSIABEvents.BrowserFinished
                }
                true
            }.collect { event -> onEventReceived(event) }
        }
    }

}