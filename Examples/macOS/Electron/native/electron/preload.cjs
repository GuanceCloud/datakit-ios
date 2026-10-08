const { contextBridge, ipcRenderer } = require('electron')
const {
  installElectronRumPreload,
} = require('@cloudcare/electron-native-adapter/preload/install')

installElectronRumPreload()

contextBridge.exposeInMainWorld('nativeHost', Object.freeze({
  getInfo: () => ipcRenderer.invoke('native-host:get-info'),
  openPopup: () => ipcRenderer.invoke('native-host:open-popup'),
  setReplayRecording: (recording) => ipcRenderer.send(
    'native-host:set-replay-recording',
    recording === true,
  ),
  rendererReady: (status) => ipcRenderer.send('native-host:renderer-ready', status),
}))
