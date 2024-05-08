const notifyThemeColors = () => {
    function doWait() {
        var colors = {};

        const element = document.createElement('div');
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

const setOverrideZoomEnabled = (shouldZoom) => {
    // we know that the HA frontend creates this meta tag, so we can be lazy
    const element = document.querySelector('meta[name="viewport"]');
    if (element === null) {
        return;
    }

    const ignoredBits = ['user-scalable', 'minimum-scale', 'maximum-scale'];
    let elements = element['content']
        .split(',')
        .filter(contentItem => {
            return ignoredBits.every(ignoredBit => !contentItem.includes(ignoredBit));
        });

    if (shouldZoom) {
        elements.push('user-scalable=yes');
    } else {
        // setting minimum/maximum scale resets existing zoom if there is one, but it doesn't play nice with
        // the overall 'page zoom' scaling that we add. users can generally unpinch 
        elements.push('user-scalable=no');
    }

    element['content'] = elements.join(',');
    console.log(`adjusted viewport to ${element['content']}`);
};

waitForHassConnection().then(({ conn }) => {
    conn.subscribeEvents(notifyThemeColors, 'themes_updated');
    conn.sendMessagePromise({type: 'frontend/get_themes'}).then(notifyThemeColors);

    // this should be moved to an event bus
    window.addEventListener('settheme', notifyThemeColors);
});
