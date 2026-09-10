declare global {
  interface NativeHostInfo {
    electronVersion: string
    platform: string
    arch: string
    surface: string
    adapterMode: 'external'
    capabilities?: Record<string, unknown>
  }

  interface NativeHostAPI {
    getInfo(): Promise<NativeHostInfo>
    openPopup(): Promise<void>
    setReplayRecording(recording: boolean): void
    rendererReady(status: 'active' | 'error'): void
  }

  interface Window {
    FTWebViewJavascriptBridge?: {
      sendEvent(serializedEvent: string): void
    }
    nativeHost?: NativeHostAPI
  }
}

export {}
