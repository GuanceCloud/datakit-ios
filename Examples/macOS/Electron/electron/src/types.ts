export type Page = 'dashboard' | 'tasks' | 'requests' | 'settings'

export type TaskStatus = 'Planned' | 'In Progress' | 'In Review' | 'Completed'

export type TaskPriority = 'High' | 'Medium' | 'Low'

export interface WorkspaceTask {
  id: string
  title: string
  project: string
  description: string
  status: TaskStatus
  priority: TaskPriority
  dueDate: string
  progress: number
  owner: string
}

export interface RequestLog {
  id: string
  label: string
  url: string
  status: number | 'ERR'
  duration: number
  time: string
  ok: boolean
}

export interface RequestDefinition {
  id: string
  label: string
  description: string
  endpoint: string
  tone: 'blue' | 'orange' | 'violet' | 'red'
}

export interface Preferences {
  compactMode: boolean
  requestSounds: boolean
}
