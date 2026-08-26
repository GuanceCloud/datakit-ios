export type Primitive = string | number | boolean
export type Context = Record<string, Primitive>

export type UploadConfiguration =
  | { datakitUrl: string; datawayUrl?: never; clientToken?: never }
  | { datakitUrl?: never; datawayUrl: string; clientToken: string }

export type DiscardStrategy = 'discard' | 'discardOldest'

export type SdkConfiguration = UploadConfiguration & {
  env?: string
  debug?: boolean
  service?: string
  autoSync?: boolean
  syncPageSize?: number
  syncSleepTime?: number
  enableDataIntegerCompatible?: boolean
  compressIntakeRequests?: boolean
  enableLimitWithDbSize?: boolean
  dbCacheLimit?: number
  dbDiscardStrategy?: DiscardStrategy
  globalContext?: Context
  groupIdentifiers?: string[]
  enableDataFilter?: boolean
  dataFilters?: Partial<Record<'logging' | 'rum', string[]>>
  remoteConfiguration?: boolean
  remoteConfigMiniUpdateInterval?: number
}

export interface UserData {
  id: string
  name?: string
  email?: string
  extra?: Context
}

export interface RemoteConfigUpdateResult {
  content: Record<string, unknown> | null
  config: Record<string, unknown> | null
}

export interface RumConfiguration {
  appId: string
  sampleRate?: number
  sessionOnErrorSampleRate?: number
  enableTraceUserAction?: boolean
  enableTraceUserView?: boolean
  enableTraceUserResource?: boolean
  enableResourceHostIP?: boolean
  enableTrackAppCrash?: boolean
  crashMonitoring?: number
  enableTrackAppFreeze?: boolean
  freezeDurationMs?: number
  enableTrackAppANR?: boolean
  errorMonitorType?: number
  deviceMetricsMonitorType?: number
  monitorFrequency?: 'default' | 'frequent' | 'rare'
  globalContext?: Context
  rumCacheLimitCount?: number
  rumDiscardStrategy?: DiscardStrategy
  enableTraceWebView?: boolean
  allowWebViewHost?: string[] | null
}

export interface RumError {
  type: string
  message: string
  stack: string
  state?: string
  attributes?: Context
}

export interface RumResourceContent {
  url: string
  httpMethod: string
  requestHeaders?: Record<string, string>
  responseHeaders?: Record<string, string>
  responseBody?: string
  statusCode?: number
}

export interface RumResourceMetrics {
  duration?: number
  dns?: number
  tcp?: number
  ssl?: number
  ttfb?: number
  transfer?: number
  firstByte?: number
}

export type LogStatus = 'info' | 'warning' | 'error' | 'critical' | 'ok' | string

export interface LoggerConfiguration {
  sampleRate?: number
  enableLinkRumData?: boolean
  enableCustomLog?: boolean
  printCustomLogToConsole?: boolean
  logCacheLimitCount?: number
  discardStrategy?: DiscardStrategy
  logLevelFilter?: Array<LogStatus | number>
  globalContext?: Context
}

export type TraceType =
  | 'ddTrace'
  | 'zipkinMulti'
  | 'zipkinSingle'
  | 'traceparent'
  | 'skywalking'
  | 'jaeger'

export interface TraceConfiguration {
  sampleRate?: number
  traceType?: TraceType
  enableLinkRumData?: boolean
  enableAutoTrace?: boolean
}

export interface SessionReplayConfiguration {
  sampleRate?: number
  sessionReplayOnErrorSampleRate?: number
  touchPrivacy?: 'show' | 'hide'
  textAndInputPrivacy?:
    | 'maskSensitiveInputs'
    | 'maskAllInputs'
    | 'maskAll'
  imagePrivacy?: 'maskNonBundledOnly' | 'maskAll' | 'maskNone'
  enableLinkRumKeys?: string[]
  enableHeatmap?: boolean
}

export type {
  AttachOptions,
  Bounds,
  BridgeStartOptions,
  BrowserWindowLike,
  WebContentsRegistration,
} from '@cloudcare/guance-electron-adapter'
export type {
  BridgeConfiguration,
  BridgeController,
  SessionLike,
  WebContentsLike,
} from '@cloudcare/guance-electron-adapter/internal'
