const forwardEventToScriptMessage = (eventName) => {
  console.log('Registering for event named', eventName)
  document.addEventListener(eventName, (event) => {
    let payload = event.detail || {'no': 'payload'};
    console.log(`Got event named ${eventName}:`, event)
    console.log(`Sending payload`, payload)
    window.webkit.messageHandlers[eventName].postMessage(payload);
  });
}

forwardEventToScriptMessage('haptic_event');
forwardEventToScriptMessage('open-external-app-configuration');

forwardEventToScriptMessage('auth-invalid');
forwardEventToScriptMessage('connected');
forwardEventToScriptMessage('disconnected');
