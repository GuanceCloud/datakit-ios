const CHANNELS = Object.freeze({
  configuration: 'guance:electron:get-configuration',
  message: 'guance:electron:web-message',
})

let installed = false

interface PreloadElectron {
  contextBridge: { exposeInMainWorld(name: string, value: unknown): void }
  ipcRenderer: {
    sendSync(channel: string): any
    send(channel: string, value: unknown): void
  }
}

export function install(electron: PreloadElectron = require('electron') as PreloadElectron): boolean {
  if (installed) return true
  const configuration = electron.ipcRenderer.sendSync(CHANNELS.configuration)
  if (!configuration?.enabled) return false
  const maximum = Number(configuration.maximumMessageBytes || 1024 * 1024)
  electron.contextBridge.exposeInMainWorld('FTWebViewJavascriptBridge', Object.freeze({
    getAllowedWebViewHosts: () => configuration.allowedWebViewHosts == null
      ? null
      : JSON.stringify(configuration.allowedWebViewHosts),
    getCapabilities: () => configuration.capabilities || '[]',
    getPrivacyLevel: () => configuration.privacyLevel || 'mask',
    sendEvent: (data: unknown): void => {
      if (typeof data !== 'string') return
      const messageQueue = JSON.stringify([{ handlerName: 'sendEvent', data }])
      if (new TextEncoder().encode(messageQueue).byteLength > maximum) return
      electron.ipcRenderer.send(CHANNELS.message, messageQueue)
    },
  }))
  installed = true
  return true
}

export const automaticallyInstalled =
  (process as NodeJS.Process & { type?: string }).type === 'renderer'
    ? install()
    : false
