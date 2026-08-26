import { GuanceElectronError } from './errors'

export type LifecycleState =
  | 'idle'
  | 'native-ready'
  | 'feature-ready'
  | 'local-bridge-ready'
  | 'shutdown'

class Lifecycle {
  state: LifecycleState = 'idle'
  rumConfigured = false
  private bridgeDisposer?: () => void

  require(states: LifecycleState[], operation: string): void {
    if (!states.includes(this.state)) {
      throw new GuanceElectronError(
        'INVALID_STATE',
        `${operation} is not allowed while Guanceelectron is ${this.state}`,
      )
    }
  }

  setBridgeDisposer(disposer: (() => void) | undefined): void {
    this.bridgeDisposer = disposer
  }

  disposeBridge(): void {
    const disposer = this.bridgeDisposer
    this.bridgeDisposer = undefined
    disposer?.()
  }

  resetForTesting(): void {
    this.state = 'idle'
    this.rumConfigured = false
    this.bridgeDisposer = undefined
  }
}

export const lifecycle = new Lifecycle()
