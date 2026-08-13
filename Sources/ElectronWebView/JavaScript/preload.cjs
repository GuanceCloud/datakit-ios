'use strict'

const CHANNELS = Object.freeze({
  configuration: 'guance:electron-rum:get-configuration',
  message: 'guance:electron-rum:message',
})

let installed = false

function install(electron = require('electron')) {
  if (installed) return true

  const { contextBridge, ipcRenderer } = electron
  if (!contextBridge || !ipcRenderer) {
    throw new TypeError('install() must run from an Electron preload script')
  }

  const configuration = ipcRenderer.sendSync(CHANNELS.configuration)
  if (!configuration?.enabled) return false

  const maximumMessageBytes = Number(
    configuration.maximumMessageBytes || 1024 * 1024,
  )

  contextBridge.exposeInMainWorld('FTWebViewJavascriptBridge', {
    getAllowedWebViewHosts: () => {
      const allowedHosts = configuration.allowedWebViewHosts
      return allowedHosts == null ? null : JSON.stringify(allowedHosts)
    },
    getCapabilities: () => configuration.capabilities || '[]',
    getPrivacyLevel: () => configuration.privacyLevel || 'mask',
    sendEvent: (data) => {
      if (typeof data !== 'string') return
      const messageQueue = JSON.stringify([
        { handlerName: 'sendEvent', data },
      ])
      if (new TextEncoder().encode(messageQueue).byteLength > maximumMessageBytes) {
        console.warn('[Guance Electron RUM] bridge message exceeds native limit')
        return
      }
      ipcRenderer.send(CHANNELS.message, messageQueue)
    },
  })

  installed = true
  return true
}

// `session.setPreloads()` executes this module as an Electron preload script.
// Exporting `install` alone is not enough: no application preload imports this
// helper, so the bridge would never reach the renderer. Keep the explicit
// export for embedding tests, but install automatically in a renderer preload.
function installAutomatically() {
  if (process.type !== 'renderer') return false
  return install()
}

const automaticallyInstalled = installAutomatically()

module.exports = { install, automaticallyInstalled }
