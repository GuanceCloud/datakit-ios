const { contextBridge, ipcRenderer } = require('electron')
const {
  installElectronRumPreload,
} = require('@cloudcare/electron-native-adapter/preload/install')

installElectronRumPreload()

contextBridge.exposeInMainWorld('orbitDesk', Object.freeze({
  getAppInfo: () => ipcRenderer.invoke('app:get-info'),
  openAuxiliaryWindow: () => ipcRenderer.invoke('app:open-auxiliary-window'),
  rendererReady: (status) => ipcRenderer.send('app:renderer-ready', status),
}))
