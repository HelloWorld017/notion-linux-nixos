# fixing tray icon and right click menu
s|this.tray.on("click",(()=>{this.onClick()}))|this.tray.setContextMenu(this.trayMenu),this.tray.on("click",(()=>{this.onClick()}))|g
s|getIcon(){[^}]*}|getIcon(){return require("path").resolve(__dirname, "trayIcon.png");}|g

# fake the useragent as windows to fix the spellchecker languages selector and other issues
s|e.setUserAgent(`${e.getUserAgent()} WantsServiceWorker`),|e.setUserAgent(`${e.getUserAgent().replace("Linux", "Windows")} WantsServiceWorker`),|g

# fully disabling auto updates
s|if("darwin"===process.platform){const e=l.systemPreferences?.getUserDefault(C,"boolean"),t=M.Store.getState().app.preferences?.isAutoUpdaterDisabled,r=M.Store.getState().app.preferences?.isAutoUpdaterOSSupportBypass,n=(0,y.isOsUnsupportedForAutoUpdates)();return Boolean(e\|\|t\|\|!r&&n)}return!1|return!0|g

# avoid running duplicated instances, fixes url opening
s|handleOpenUrl);else if("win32"===process.platform)|handleOpenUrl);else if("linux"===process.platform)|g
s|async function(){(0,E.setupCrashReporter)(),|o.app.requestSingleInstanceLock() ? async function(){(0,E.setupCrashReporter)(),|g
s|setupCleanup)()}()}()|setupCleanup)()}()}() : o.app.quit();|g

# use the windows version of the tray menu
s|r="win32"===process.platform?function(e,t)|r="linux"===process.platform?function(e,t)|g
