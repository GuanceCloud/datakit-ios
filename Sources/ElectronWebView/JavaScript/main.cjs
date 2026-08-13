'use strict'

const CHANNELS = Object.freeze({
  configuration: 'guance:electron-rum:get-configuration',
  message: 'guance:electron-rum:message',
})

const TAKE_SUBSEQUENT_FULL_SNAPSHOT = 'takeSubsequentFullSnapshot'
const TAKE_SUBSEQUENT_FULL_SNAPSHOT_SCRIPT =
  'window.DATAFLUX_RUM?.takeSubsequentFullSnapshot()'
const DEFAULT_PRELOAD_PATH = require.resolve('./preload.cjs')
const REQUIRED_NATIVE_METHODS = [
  'getElectronBridgeConfiguration',
  'registerElectronWebContents',
  'updateElectronWebContents',
  'receiveElectronWebContentsMessage',
  'unregisterElectronWebContents',
]

let nextSlotID = Date.now() * 1000
let defaultIntegration

function allocateSlotID() {
  const slotID = nextSlotID
  nextSlotID += 1
  return slotID
}

function parseConfiguration(nativeBridge) {
  const value = nativeBridge.getElectronBridgeConfiguration()
  const parsed = typeof value === 'string' ? JSON.parse(value) : value
  if (parsed && typeof parsed === 'object') {
    return Object.freeze({
      ...parsed,
      enableTraceWebView: parsed.enableTraceWebView === true,
      allowedWebViewHosts: Array.isArray(parsed.allowedWebViewHosts)
        ? [...parsed.allowedWebViewHosts]
        : null,
    })
  }
  throw new TypeError('Native bridge returned an invalid configuration')
}

function normalizeBounds(bounds) {
  if (bounds == null) return null
  const normalized = {
    x: Number(bounds.x),
    y: Number(bounds.y),
    width: Number(bounds.width),
    height: Number(bounds.height),
  }
  if (
    !Number.isFinite(normalized.x) ||
    !Number.isFinite(normalized.y) ||
    !Number.isFinite(normalized.width) ||
    !Number.isFinite(normalized.height) ||
    normalized.width <= 0 ||
    normalized.height <= 0
  ) {
    throw new TypeError('WebContents bounds must be a finite non-empty rectangle')
  }
  return normalized
}

function hostFromURL(value) {
  if (typeof value !== 'string' || value.length === 0) return ''
  try {
    return new URL(value).hostname.toLowerCase()
  } catch {
    return ''
  }
}

function isAllowedHost(allowedHosts, url) {
  if (allowedHosts == null) return true
  const currentHost = hostFromURL(url)
  if (!currentHost) return false
  return allowedHosts.some((value) => {
    const allowedHost = String(value).trim().toLowerCase()
    return (
      allowedHost.length > 0 &&
      (currentHost === allowedHost || currentHost.endsWith(`.${allowedHost}`))
    )
  })
}

function assertBrowserWindow(browserWindow) {
  if (
    !browserWindow ||
    !browserWindow.webContents ||
    typeof browserWindow.getNativeWindowHandle !== 'function'
  ) {
    throw new TypeError('attach expects an Electron BrowserWindow')
  }
}

function assertNativeBridge(nativeBridge) {
  if (!nativeBridge || typeof nativeBridge !== 'object') {
    throw new TypeError('attach expects an initialized native bridge')
  }
  for (const method of REQUIRED_NATIVE_METHODS) {
    if (typeof nativeBridge[method] !== 'function') {
      throw new TypeError(`Native bridge is missing ${method}()`)
    }
  }
}

function createElectronRUM(electron) {
  if (!electron?.ipcMain) {
    throw new TypeError('createElectronRUM expects Electron ipcMain')
  }

  const { ipcMain, app, BrowserWindow, session } = electron
  const registrations = new Map()
  let disposed = false

  const getRegistration = (sender) => {
    const registration = registrations.get(sender?.id)
    return registration?.webContents === sender ? registration : undefined
  }

  const onGetConfiguration = (event) => {
    const registration = getRegistration(event.sender)
    if (!registration || !registration.hostAllowed) {
      event.returnValue = { enabled: false }
      return
    }

    event.returnValue = {
      enabled: true,
      ...registration.configuration,
    }
  }

  const onMessage = (event, messageQueue) => {
    const registration = getRegistration(event.sender)
    if (
      !registration ||
      !registration.hostAllowed ||
      typeof messageQueue !== 'string'
    ) return

    const handled = registration.nativeBridge.receiveElectronWebContentsMessage(
      registration.webContents.id,
      messageQueue,
    )
    if (!handled) {
      registration.logger.warn(
        `[Guance Electron RUM] native SDK rejected WebContents ${registration.webContents.id} message`,
      )
    }
  }

  ipcMain.on(CHANNELS.configuration, onGetConfiguration)
  ipcMain.on(CHANNELS.message, onMessage)

  function dispatchRegistrationNativeCommand(registration, command) {
    if (command !== TAKE_SUBSEQUENT_FULL_SNAPSHOT) return false
    if (registration.detached || registration.webContents.isDestroyed?.()) {
      return true
    }
    if (typeof registration.webContents.executeJavaScript !== 'function') {
      registration.logger.warn(
        `[Guance Electron RUM] WebContents ${registration.webContents.id} cannot execute replay command`,
      )
      return false
    }

    Promise.resolve(
      registration.webContents.executeJavaScript(
        TAKE_SUBSEQUENT_FULL_SNAPSHOT_SCRIPT,
      ),
    ).catch((error) => {
      registration.logger.warn(
        `[Guance Electron RUM] failed to request WebContents ${registration.webContents.id} full snapshot`,
        error,
      )
    })
    return true
  }

  function detachRegistration(registration) {
    if (!registration || registration.detached) return
    registration.detached = true
    registrations.delete(registration.webContents.id)
    registration.browserWindow.removeListener('resize', registration.syncLayout)
    registration.browserWindow.removeListener('closed', registration.detach)
    registration.webContents.removeListener(
      'did-start-navigation',
      registration.syncHost,
    )
    registration.webContents.removeListener('destroyed', registration.detach)
    registration.nativeBridge.unregisterElectronWebContents(
      registration.webContents.id,
    )
  }

  function attach(browserWindow, nativeBridge, options = {}) {
    if (disposed) throw new Error('Guance Electron RUM integration is disposed')
    assertBrowserWindow(browserWindow)
    assertNativeBridge(nativeBridge)

    const webContents = options.webContents || browserWindow.webContents
    if (!webContents || !Number.isSafeInteger(webContents.id)) {
      throw new TypeError('attach requires a WebContents with a numeric id')
    }
    if (registrations.has(webContents.id)) {
      throw new Error(`WebContents ${webContents.id} is already attached`)
    }

    const slotID = options.slotID ?? allocateSlotID()
    const logger = options.logger || console
    const configuration = options.configuration || parseConfiguration(nativeBridge)
    let visible = options.visible ?? true
    let zIndex = options.zIndex ?? 0
    let bounds = normalizeBounds(
      typeof options.getBounds === 'function'
        ? options.getBounds()
        : options.bounds,
    )
    let hostAllowed = isAllowedHost(
      configuration.allowedWebViewHosts,
      webContents.getURL?.(),
    )

    if (!Number.isSafeInteger(slotID) || slotID <= 0) {
      throw new TypeError('slotID must be a positive safe integer')
    }
    if (!Number.isInteger(zIndex)) {
      throw new TypeError('zIndex must be an integer')
    }

    const nativeWindowHandle = browserWindow.getNativeWindowHandle()
    const registered = nativeBridge.registerElectronWebContents(
      nativeWindowHandle,
      webContents.id,
      slotID,
      Boolean(visible && hostAllowed),
      zIndex,
      bounds,
    )
    if (!registered) {
      throw new Error(
        `Native SDK could not register WebContents ${webContents.id}; initialize native RUM and Electron WebView support before attach()`,
      )
    }

    const registration = {
      browserWindow,
      webContents,
      nativeBridge,
      nativeWindowHandle,
      slotID,
      logger,
      configuration,
      hostAllowed,
      visible: Boolean(visible),
      getBounds: options.getBounds,
      detached: false,
      syncLayout: undefined,
      syncHost: undefined,
      detach: undefined,
    }

    const syncLayout = () => {
      if (registration.detached || webContents.isDestroyed?.()) return false
      if (typeof registration.getBounds === 'function') {
        bounds = normalizeBounds(registration.getBounds())
      }
      const updated = nativeBridge.updateElectronWebContents(
        nativeWindowHandle,
        webContents.id,
        Boolean(visible && registration.hostAllowed),
        zIndex,
        bounds,
      )
      if (!updated) {
        logger.warn(
          `[Guance Electron RUM] failed to update WebContents ${webContents.id}`,
        )
      }
      return Boolean(updated)
    }

    const syncHost = (_event, url, isInPlace, isMainFrame) => {
      if (isMainFrame === false || isInPlace === true) return
      const nextHostAllowed = isAllowedHost(
        configuration.allowedWebViewHosts,
        url,
      )
      if (registration.hostAllowed === nextHostAllowed) return
      registration.hostAllowed = nextHostAllowed
      syncLayout()
    }

    const detach = () => detachRegistration(registration)
    registration.syncLayout = syncLayout
    registration.syncHost = syncHost
    registration.detach = detach
    registrations.set(webContents.id, registration)

    browserWindow.on('resize', syncLayout)
    browserWindow.once('closed', detach)
    webContents.on('did-start-navigation', syncHost)
    webContents.once('destroyed', detach)

    const controller = Object.freeze({
      webContentsID: webContents.id,
      slotID,
      update(next = {}) {
        if (Object.prototype.hasOwnProperty.call(next, 'visible')) {
          visible = Boolean(next.visible)
          registration.visible = visible
        }
        if (Object.prototype.hasOwnProperty.call(next, 'zIndex')) {
          if (!Number.isInteger(next.zIndex)) {
            throw new TypeError('zIndex must be an integer')
          }
          zIndex = next.zIndex
        }
        if (Object.prototype.hasOwnProperty.call(next, 'bounds')) {
          bounds = normalizeBounds(next.bounds)
        }
        return syncLayout()
      },
      handleNativeCommand(commandOrEvent) {
        let command = commandOrEvent
        if (typeof commandOrEvent === 'string') {
          const match = /^electron-command:(\d+):(.+)$/.exec(commandOrEvent)
          if (match) {
            if (Number.parseInt(match[1], 10) !== webContents.id) return false
            command = match[2]
          }
        }
        return dispatchRegistrationNativeCommand(registration, command)
      },
      detach,
    })

    return controller
  }

  function bootstrap(options = {}) {
    if (disposed) throw new Error('Guance Electron RUM integration is disposed')
    if (!options || typeof options !== 'object') {
      throw new TypeError('bootstrap expects an options object')
    }

    const { nativeBridge } = options
    assertNativeBridge(nativeBridge)
    const configuration = parseConfiguration(nativeBridge)
    const logger = options.logger || console
    const preloadPath = options.preloadPath || DEFAULT_PRELOAD_PATH
    if (typeof preloadPath !== 'string' || preloadPath.length === 0) {
      throw new TypeError('preloadPath must be a non-empty file path')
    }

    const controllers = new Map()
    const browserViewControllers = new Map()
    const windowHooks = new Map()
    const browserViewHooks = new Map()
    let clientDisposed = false
    let autoAttachListener
    let webContentsCreatedListener

    function installNativeCommandHandler() {
      if (typeof nativeBridge.setElectronCommandHandler !== 'function') {
        return false
      }
      nativeBridge.setElectronCommandHandler((webContentsID, command) =>
        dispatchClientNativeCommand(webContentsID, command),
      )
      return true
    }

    function installPreload(targetSession) {
      if (
        !targetSession ||
        typeof targetSession.getPreloads !== 'function' ||
        typeof targetSession.setPreloads !== 'function'
      ) {
        return false
      }
      const preloads = targetSession.getPreloads()
      if (preloads.includes(preloadPath)) return true
      targetSession.setPreloads([...preloads, preloadPath])
      return true
    }

    function installPreloadForWebContents(webContents) {
      return installPreload(webContents?.session)
    }

    function attachManaged(browserWindow, attachOptions = {}) {
      if (clientDisposed) {
        throw new Error('Guance Electron RUM client is disposed')
      }

      const webContents = attachOptions.webContents || browserWindow.webContents
      const existing = controllers.get(webContents?.id)
      if (existing) {
        const next = {}
        for (const key of ['visible', 'zIndex', 'bounds']) {
          if (Object.prototype.hasOwnProperty.call(attachOptions, key)) {
            next[key] = attachOptions[key]
          }
        }
        if (Object.keys(next).length > 0) {
          existing.update(next)
        }
        return existing
      }

      installPreloadForWebContents(webContents)

      const attachedController = attach(
        browserWindow,
        nativeBridge,
        { ...attachOptions, configuration },
      )
      const webContentsID = attachedController.webContentsID
      const removeController = () => controllers.delete(webContentsID)
      browserWindow.once('closed', removeController)
      webContents.once('destroyed', removeController)

      const detach = () => {
        browserWindow.removeListener('closed', removeController)
        webContents.removeListener('destroyed', removeController)
        removeController()
        attachedController.detach()
      }
      const controller = Object.freeze({
        webContentsID,
        slotID: attachedController.slotID,
        update: attachedController.update,
        handleNativeCommand: attachedController.handleNativeCommand,
        detach,
      })
      controllers.set(webContentsID, controller)
      return controller
    }

    function getBrowserViews(browserWindow) {
      if (typeof browserWindow.getBrowserViews !== 'function') return []
      const views = browserWindow.getBrowserViews()
      return Array.isArray(views) ? views : []
    }

    function controllersForBrowserWindow(browserWindow) {
      let viewControllers = browserViewControllers.get(browserWindow)
      if (!viewControllers) {
        viewControllers = new Map()
        browserViewControllers.set(browserWindow, viewControllers)
      }
      return viewControllers
    }

    function observeBrowserViewBounds(browserWindow, browserView) {
      if (
        browserViewHooks.has(browserView) ||
        typeof browserView.setBounds !== 'function'
      ) {
        return
      }
      const originalSetBounds = browserView.setBounds
      const wrappedSetBounds = function wrappedSetBounds(...args) {
        const result = originalSetBounds.apply(this, args)
        const controller = browserViewControllers
          .get(browserWindow)
          ?.get(browserView)
        if (controller) controller.update()
        return result
      }
      browserView.setBounds = wrappedSetBounds
      browserViewHooks.set(browserView, {
        originalSetBounds,
        wrappedSetBounds,
      })
    }

    function attachBrowserView(browserWindow, browserView, attachOptions = {}) {
      if (
        !browserView ||
        !browserView.webContents ||
        typeof browserView.getBounds !== 'function'
      ) {
        throw new TypeError(
          'attachWebContents expects an Electron 22 BrowserView',
        )
      }

      const viewControllers = controllersForBrowserWindow(browserWindow)
      let controller = viewControllers.get(browserView)
      if (!controller || controllers.get(controller.webContentsID) !== controller) {
        controller = attachManaged(browserWindow, {
          ...attachOptions,
          webContents: browserView.webContents,
          getBounds: () => browserView.getBounds(),
        })
        viewControllers.set(browserView, controller)
      } else {
        const next = {}
        for (const key of ['visible', 'zIndex']) {
          if (Object.prototype.hasOwnProperty.call(attachOptions, key)) {
            next[key] = attachOptions[key]
          }
        }
        controller.update(next)
      }
      installPreloadForWebContents(browserView.webContents)
      observeBrowserViewBounds(browserWindow, browserView)
      return controller
    }

    function reconcileBrowserViews(browserWindow) {
      if (clientDisposed || !configuration.enableTraceWebView) return
      const attachedViews = getBrowserViews(browserWindow)
      const attachedSet = new Set(attachedViews)
      attachedViews.forEach((browserView, zIndex) => {
        try {
          attachBrowserView(browserWindow, browserView, {
            visible: true,
            zIndex,
          })
        } catch (error) {
          logger.error(
            '[Guance Electron RUM] failed to auto-attach BrowserView',
            error,
          )
        }
      })

      const viewControllers = browserViewControllers.get(browserWindow)
      if (!viewControllers) return
      for (const [browserView, controller] of viewControllers) {
        if (!attachedSet.has(browserView)) {
          controller.update({ visible: false })
        }
      }
    }

    function installBrowserViewHooks(browserWindow) {
      if (windowHooks.has(browserWindow)) return

      const hooks = []
      const wrap = (methodName) => {
        const original = browserWindow[methodName]
        if (typeof original !== 'function') return
        const wrapped = function wrappedBrowserViewMethod(...args) {
          const result = original.apply(this, args)
          reconcileBrowserViews(browserWindow)
          return result
        }
        browserWindow[methodName] = wrapped
        hooks.push({ methodName, original, wrapped })
      }

      wrap('addBrowserView')
      wrap('setBrowserView')
      wrap('removeBrowserView')
      wrap('setTopBrowserView')
      windowHooks.set(browserWindow, hooks)
      reconcileBrowserViews(browserWindow)
    }

    function restoreBrowserViewHooks(browserWindow) {
      const hooks = windowHooks.get(browserWindow)
      if (hooks) {
        for (const { methodName, original, wrapped } of hooks) {
          if (browserWindow[methodName] === wrapped) {
            browserWindow[methodName] = original
          }
        }
      }
      windowHooks.delete(browserWindow)

      const viewControllers = browserViewControllers.get(browserWindow)
      if (viewControllers) {
        for (const browserView of viewControllers.keys()) {
          const hook = browserViewHooks.get(browserView)
          if (hook && browserView.setBounds === hook.wrappedSetBounds) {
            browserView.setBounds = hook.originalSetBounds
          }
          browserViewHooks.delete(browserView)
        }
      }
      browserViewControllers.delete(browserWindow)
    }

    function attachWindow(browserWindow, attachOptions = {}) {
      const controller = attachManaged(browserWindow, attachOptions)
      if (configuration.enableTraceWebView) {
        installBrowserViewHooks(browserWindow)
      }
      return controller
    }

    function attachWebContents(browserWindow, browserView, attachOptions = {}) {
      installBrowserViewHooks(browserWindow)
      return attachBrowserView(browserWindow, browserView, attachOptions)
    }

    function startAutoAttachWindows() {
      if (
        options.autoAttach === false ||
        !configuration.enableTraceWebView ||
        !app?.on ||
        !BrowserWindow?.getAllWindows
      ) {
        return false
      }

      const autoAttach = (browserWindow) => {
        try {
          attachWindow(browserWindow)
        } catch (error) {
          logger.error(
            '[Guance Electron RUM] failed to auto-attach BrowserWindow',
            error,
          )
        }
      }
      installPreload(session?.defaultSession)
      webContentsCreatedListener = (_event, webContents) => {
        installPreloadForWebContents(webContents)
      }
      app.on('web-contents-created', webContentsCreatedListener)
      autoAttachListener = (_event, browserWindow) => autoAttach(browserWindow)
      app.on('browser-window-created', autoAttachListener)
      for (const browserWindow of BrowserWindow.getAllWindows()) {
        autoAttach(browserWindow)
      }
      return true
    }

    function dispatchClientNativeCommand(webContentsID, command) {
      if (clientDisposed || !controllers.has(webContentsID)) return false
      return dispatchNativeCommand(webContentsID, command)
    }

    function disposeClient() {
      if (clientDisposed) return
      clientDisposed = true
      if (autoAttachListener) {
        app.removeListener('browser-window-created', autoAttachListener)
        autoAttachListener = undefined
      }
      if (webContentsCreatedListener) {
        app.removeListener('web-contents-created', webContentsCreatedListener)
        webContentsCreatedListener = undefined
      }
      for (const browserWindow of [...windowHooks.keys()]) {
        restoreBrowserViewHooks(browserWindow)
      }
      for (const controller of [...controllers.values()]) {
        controller.detach()
      }
      controllers.clear()
      if (typeof nativeBridge.setElectronCommandHandler === 'function') {
        nativeBridge.setElectronCommandHandler(null)
      }
    }

    installNativeCommandHandler()
    const autoAttachEnabled = startAutoAttachWindows()

    return Object.freeze({
      attachWindow,
      attachWebContents,
      autoAttachEnabled,
      configuration,
      dispatchNativeCommand: dispatchClientNativeCommand,
      dispose: disposeClient,
    })
  }

  function dispatchNativeCommand(webContentsID, command) {
    const registration = registrations.get(webContentsID)
    if (!registration) return false
    return dispatchRegistrationNativeCommand(registration, command)
  }

  function dispose() {
    if (disposed) return
    disposed = true
    for (const registration of [...registrations.values()]) {
      detachRegistration(registration)
    }
    ipcMain.removeListener(CHANNELS.configuration, onGetConfiguration)
    ipcMain.removeListener(CHANNELS.message, onMessage)
  }

  return Object.freeze({
    attach,
    bootstrap,
    // `initialize` remains an alias for integrations that adopted the first
    // version of this helper. New integrations should use `bootstrap` because
    // it describes the one-time Electron Main setup more precisely.
    initialize: bootstrap,
    dispatchNativeCommand,
    dispose,
  })
}

function getDefaultIntegration() {
  if (!defaultIntegration) {
    defaultIntegration = createElectronRUM(require('electron'))
  }
  return defaultIntegration
}

module.exports = {
  bootstrap: (...args) => getDefaultIntegration().bootstrap(...args),
  initialize: (...args) => getDefaultIntegration().bootstrap(...args),
  attach: (...args) => getDefaultIntegration().attach(...args),
  dispatchNativeCommand: (...args) =>
    getDefaultIntegration().dispatchNativeCommand(...args),
  createElectronRUM,
}
