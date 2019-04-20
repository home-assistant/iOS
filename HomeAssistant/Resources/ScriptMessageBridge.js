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

const handleThemeUpdate = (event) => {
  var payload = event.data || event;
  let themeName = payload.default_theme;
  if(themeName === 'default') {
    window.webkit.messageHandlers.themesUpdated.postMessage({
      'name': themeName
    });
  } else {
    window.webkit.messageHandlers.themesUpdated.postMessage({
      'name': themeName,
      'styles': payload.themes[themeName]
    });
  }
}

window.hassConnection.then(({ conn }) => {
  conn.sendMessagePromise({type: 'frontend/get_themes'}).then(handleThemeUpdate);
  conn.subscribeEvents(handleThemeUpdate, 'themes_updated');
});
