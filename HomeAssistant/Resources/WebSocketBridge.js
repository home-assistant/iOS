const handleThemeUpdate = (event) => {
  var payload = event.data || event;
  let themeName = payload.default_theme;
  if(themeName === 'default') {
    window.webkit.messageHandlers.themesUpdated.postMessage({ 'name': themeName });
  } else {
    window.webkit.messageHandlers.themesUpdated.postMessage({ 'name': themeName, 'styles': payload.themes[themeName] });
  }
}

window.hassConnection.then(({ conn }) => {
  conn.sendMessagePromise({type: 'auth/current_user'}).then((user) => {
    window.webkit.messageHandlers.currentUser.postMessage(user);
  });
  conn.sendMessagePromise({type: 'frontend/get_themes'}).then(handleThemeUpdate);
  conn.subscribeEvents(handleThemeUpdate, 'themes_updated');
});
