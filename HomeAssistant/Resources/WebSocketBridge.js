const notifyThemeColors = () => {
    function doWait() {
        var colors = {};

        let element = document.createElement('div');
        document.body.appendChild(element);
        element.style.display = 'none';

        [
            '--app-header-background-color',
            '--primary-background-color',
            '--text-primary-color',
            '--primary-color',
        ].forEach(colorVar => {
            // this element allows us to get a canonical rgb/rgba representation rather than any string value
            element.style.backgroundColor = 'var(' + colorVar + ')';
            colors[colorVar] = getComputedStyle(element).getPropertyValue('background-color');
        });

        document.body.removeChild(element);

        window.webkit.messageHandlers.updateThemeColors.postMessage(colors);
    }
    // wait a short amount for the computed styles to change
    setTimeout(doWait, 100);
}

const waitForHassConnection = () => {
    var loopCount = 0;
    return new Promise((resolve, reject) => {
        (function doWait() {
            if (window.hassConnection) {
                resolve(window.hassConnection);
            } else {
                // really we just need to wait a run loop, but better safe than sorry for backoff
                setTimeout(doWait, loopCount * 10);
                loopCount++;
            }
        })();
    });
}

const checkForMissingHassConnectionAndReload = () => {
    // this is invoked when we think connect status is changed, to avoid the user needing to tap reload
    window.hassConnection.catch(() => {
        // this is the action taken by the frontend when the user taps, anyway -- we're just doing it for them
        location.reload();
    });
};

waitForHassConnection().then(({ conn }) => {
    conn.sendMessagePromise({type: 'auth/current_user'}).then((user) => {
        window.webkit.messageHandlers.currentUser.postMessage(user);
    });
    conn.subscribeEvents(notifyThemeColors, 'themes_updated');
    conn.sendMessagePromise({type: 'frontend/get_themes'}).then(notifyThemeColors);

    // this should be moved to an event bus
    window.addEventListener('settheme', notifyThemeColors);
});
