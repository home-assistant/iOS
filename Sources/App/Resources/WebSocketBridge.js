// Every CSS custom property the current theme resolves to, so native screens can be drawn in the
// user's colours. The names are discovered rather than hardcoded: a theme is free to declare
// properties the app has never heard of, and the ones the frontend itself declares move between
// releases. Two sources cover both -- the frontend applies the selected theme by setting properties
// inline on <html>, and its own defaults are declared by the document's stylesheets.
const collectThemeVariableNames = () => {
    const names = new Set();

    const inlineStyle = document.documentElement.style;
    for (let i = 0; i < inlineStyle.length; i++) {
        const name = inlineStyle.item(i);
        if (name.startsWith('--')) {
            names.add(name);
        }
    }

    const collectFromRules = (rules, depth) => {
        // @media / @supports blocks nest the dark-theme declarations one level down. The bound is
        // paranoia about a pathological stylesheet, not a shape the frontend actually produces.
        if (depth > 8) {
            return;
        }
        for (const rule of Array.from(rules)) {
            if (rule.style) {
                for (let i = 0; i < rule.style.length; i++) {
                    const name = rule.style.item(i);
                    if (name.startsWith('--')) {
                        names.add(name);
                    }
                }
            }
            if (rule.cssRules) {
                collectFromRules(rule.cssRules, depth + 1);
            }
        }
    };

    for (const sheet of Array.from(document.styleSheets)) {
        try {
            // Reading cssRules throws for a cross-origin stylesheet; skip it rather than lose the rest.
            if (sheet.cssRules) {
                collectFromRules(sheet.cssRules, 0);
            }
        } catch (error) {
            continue;
        }
    }

    return Array.from(names).sort();
};

// Resolve every name to its computed value, plus a canonical colour when it is one.
//
// A probe element per property, all measured after they are in the document, keeps this to a single
// style recalculation: setting and reading one shared element per property would force a synchronous
// recalc for each of the several hundred of them.
const resolveThemeVariables = (names) => {
    const computedRoot = getComputedStyle(document.documentElement);

    const container = document.createElement('div');
    container.style.display = 'none';
    document.body.appendChild(container);

    const probes = names.map(name => {
        const probe = document.createElement('div');
        // background-color keeps the value only if it parses as a colour, so the computed result is
        // both the canonical rgb/rgba representation and the test for whether this is a colour at all.
        probe.style.backgroundColor = 'var(' + name + ')';
        container.appendChild(probe);
        return probe;
    });

    try {
        return names.map((name, index) => {
            const value = computedRoot.getPropertyValue(name).trim();
            const computedColor = getComputedStyle(probes[index]).getPropertyValue('background-color');
            // rgba(0, 0, 0, 0) is also what an unparseable value falls back to, so a genuinely
            // transparent property is told apart by its own declared value.
            const isColor = computedColor !== 'rgba(0, 0, 0, 0)' || value === 'transparent';
            return {
                name: name,
                value: value,
                color: isColor ? computedColor : null,
            };
        }).filter(variable => variable.value.length > 0 || variable.color !== null);
    } finally {
        // The probes must come back out even if reading one threw, or every theme change would leave
        // several hundred more of them behind in the document.
        document.body.removeChild(container);
    }
};

// The frontend knows which appearance it resolved the theme in; the app would otherwise have to infer
// it from the system trait, which is wrong whenever the user pins the frontend to light or dark.
const currentThemeSettings = () => {
    const themes = document.querySelector('home-assistant')?.hass?.themes;
    return {
        themeName: themes?.theme ?? null,
        darkMode: themes?.darkMode ?? null,
    };
};

const notifyThemeColors = () => {
    function doWait() {
        var colors = {};

        const element = document.createElement('div');
        document.body.appendChild(element);
        element.style.display = 'none';

        [
            '--app-header-background-color',
            '--app-theme-color',
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

        try {
            const settings = currentThemeSettings();
            window.webkit.messageHandlers.updateThemeVariables.postMessage({
                themeName: settings.themeName,
                darkMode: settings.darkMode,
                variables: resolveThemeVariables(collectThemeVariableNames()),
            });
        } catch (error) {
            // The five colours above are what the status bar needs and they are already sent; the full
            // set is an enhancement, so a failure here must not take them down with it.
            window.webkit.messageHandlers.logError.postMessage({
                "message": JSON.stringify('failed to collect theme variables: ' + error),
            });
        }
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

// A back/forward navigation can restore this document from WebKit's page cache instead of loading it
// again. Nothing re-runs when that happens -- neither this script nor the frontend's bootstrap -- so the
// frontend never announces `frontend/loaded` a second time and the app would keep its stand-by loader up
// over a page that is already alive. `pageshow` with `persisted` set is the only signal that the restore
// happened, and this document's own `hassConnection` is the only thing that knows whether its frontend
// ever came up. That promise is already settled by the time we get here, so it resolves right away or
// never -- a page cached mid-load stays silent and the app keeps waiting for it, as it should.
window.addEventListener('pageshow', (event) => {
    if (!event.persisted || !window.hassConnection) {
        return;
    }
    window.hassConnection.then(() => {
        window.webkit?.messageHandlers?.frontendRestored?.postMessage({ type: 'frontend/restored' });
    }).catch(() => {});
});
