import './styles.css'
import { initialTasks, pageNames, requestDefinitions } from './data'
import { icon } from './icons'
import {
  getRumRuntimeState,
  initializeRum,
  isSessionReplayRecording,
  reportError,
  sendLog,
  startRumView,
  trackAction,
  type RumRuntimeState,
} from './rum'
import type {
  Page,
  Preferences,
  RequestLog,
  TaskPriority,
  TaskStatus,
  WorkspaceTask,
} from './types'

const TASKS_STORAGE_KEY = 'orbitdesk.tasks.v2'
const PREFERENCES_STORAGE_KEY = 'orbitdesk.preferences.v1'
const surfacePage = new URLSearchParams(window.location.search).get('surface')
const initialSurfacePage: Page | null =
  surfacePage === 'dashboard' || surfacePage === 'tasks' || surfacePage === 'requests'
    ? surfacePage
    : null

const rootElement = document.querySelector<HTMLDivElement>('#app')
const toastRootElement = document.querySelector<HTMLDivElement>('#toast-root')

if (!rootElement || !toastRootElement) {
  throw new Error('OrbitDesk root element is missing')
}

const root = rootElement
const toastRoot = toastRootElement

interface ApplicationState {
  page: Page
  tasks: WorkspaceTask[]
  taskQuery: string
  statusFilter: TaskStatus | 'All'
  selectedTaskId: string | null
  modalOpen: boolean
  requestLogs: RequestLog[]
  requestBusy: string | null
  requestPayload: unknown
  requestPayloadLabel: string
  preferences: Preferences
}

const state: ApplicationState = {
  page: initialSurfacePage || 'dashboard',
  tasks: loadTasks(),
  taskQuery: '',
  statusFilter: 'All',
  selectedTaskId: null,
  modalOpen: false,
  requestLogs: [],
  requestBusy: null,
  requestPayload: null,
  requestPayloadLabel: 'No request sent yet',
  preferences: loadPreferences(),
}

let appInfo: AppInfo = {
  name: 'OrbitDesk',
  version: '1.0.0',
  electronVersion: 'browser preview',
  chromeVersion: navigator.userAgent,
  platform: 'browser',
  arch: 'unknown',
  adapterMode: 'managed',
}

let rumState: RumRuntimeState = getRumRuntimeState()

function loadTasks(): WorkspaceTask[] {
  try {
    const stored = localStorage.getItem(TASKS_STORAGE_KEY)
    if (stored) return JSON.parse(stored) as WorkspaceTask[]
  } catch (error) {
    console.warn('Could not load saved tasks', error)
  }
  return structuredClone(initialTasks)
}

function loadPreferences(): Preferences {
  try {
    const stored = localStorage.getItem(PREFERENCES_STORAGE_KEY)
    if (stored) return JSON.parse(stored) as Preferences
  } catch (error) {
    console.warn('Could not load preferences', error)
  }
  return { compactMode: false, requestSounds: true }
}

function saveTasks(): void {
  localStorage.setItem(TASKS_STORAGE_KEY, JSON.stringify(state.tasks))
}

function savePreferences(): void {
  localStorage.setItem(PREFERENCES_STORAGE_KEY, JSON.stringify(state.preferences))
}

function escapeHtml(value: unknown): string {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

function formatDate(value: string): string {
  const date = new Date(`${value}T00:00:00`)
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' }).format(date)
}

function todayGreeting(): string {
  const hour = new Date().getHours()
  if (hour < 11) return 'Good morning'
  if (hour < 14) return 'Good afternoon'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
}

function taskCounts() {
  const completed = state.tasks.filter((task) => task.status === 'Completed').length
  const inProgress = state.tasks.filter((task) => task.status === 'In Progress').length
  const review = state.tasks.filter((task) => task.status === 'In Review').length
  const averageProgress =
    state.tasks.length > 0
      ? Math.round(state.tasks.reduce((total, task) => total + task.progress, 0) / state.tasks.length)
      : 0
  return { completed, inProgress, review, averageProgress }
}

function renderShell(): void {
  const rumIndicatorClass =
    rumState.status === 'active' ? 'is-active' : rumState.status === 'error' ? 'is-error' : ''

  root.innerHTML = `
    <div class="app-shell ${state.preferences.compactMode ? 'compact' : ''}">
      <aside class="sidebar">
        <div class="drag-strip" aria-hidden="true"></div>
        <div class="brand">
          <div class="brand-mark"><span></span><i></i></div>
          <div>
            <strong>OrbitDesk</strong>
            <small>Personal workspace</small>
          </div>
        </div>

        <nav class="sidebar-nav" aria-label="Main navigation">
          <span class="nav-section">Workspace</span>
          ${navItem('dashboard', 'Dashboard', 'dashboard')}
          ${navItem('tasks', 'Tasks', 'tasks', state.tasks.length)}
          ${navItem('requests', 'Request Lab', 'requests')}
          <span class="nav-section secondary">System</span>
          ${navItem('settings', 'Settings', 'settings')}
        </nav>

        <div class="sidebar-card">
          <div class="sidebar-card-icon">${icon('activity', 19)}</div>
          <div>
            <strong>Observability status</strong>
            <span><i class="status-dot ${rumIndicatorClass}"></i>${rumStatusLabel()}</span>
          </div>
        </div>

        <div class="profile">
          <div class="avatar">HL</div>
          <div><strong>Local User</strong><span>macOS workspace</span></div>
          ${icon('more', 18)}
        </div>
      </aside>

      <main class="main-area">
        <header class="topbar">
          <div>
            <p class="eyebrow">${new Intl.DateTimeFormat('en-US', {
              year: 'numeric',
              month: 'long',
              day: 'numeric',
              weekday: 'short',
            }).format(new Date())}</p>
            <h1>${pageNames[state.page]}</h1>
          </div>
          <div class="topbar-actions">
            <button class="secondary-button compact" data-action="open-auxiliary-window" data-guance-action-name="Open auxiliary Electron window">
              ${icon('plus', 16)} Open auxiliary window
            </button>
            <button class="icon-button" data-action="open-settings" aria-label="Open settings" data-guance-action-name="Open settings">
              ${icon('settings', 18)}
            </button>
            <button class="primary-button" data-action="open-task-modal" data-guance-action-name="New task">
              ${icon('plus', 17)} New task
            </button>
          </div>
        </header>
        <section id="page-content" class="page-content">${renderCurrentPage()}</section>
      </main>
      ${state.modalOpen ? renderTaskModal() : ''}
    </div>
  `
}

function navItem(page: Page, label: string, iconName: Parameters<typeof icon>[0], count?: number): string {
  return `
    <button
      class="nav-item ${state.page === page ? 'active' : ''}"
      data-action="navigate"
      data-page="${page}"
      data-guance-action-name="Navigate to ${label}"
    >
      ${icon(iconName, 19)}
      <span>${label}</span>
      ${count === undefined ? '' : `<b>${count}</b>`}
    </button>
  `
}

function rumStatusLabel(): string {
  if (rumState.status === 'active') return 'RUM active'
  if (rumState.status === 'error') return 'RUM initialization failed'
  return 'Waiting for Native SDK bridge'
}

function renderCurrentPage(): string {
  switch (state.page) {
    case 'dashboard':
      return renderDashboard()
    case 'tasks':
      return renderTasks()
    case 'requests':
      return renderRequests()
    case 'settings':
      return renderSettings()
  }
}

function renderDashboard(): string {
  const { completed, inProgress, review, averageProgress } = taskCounts()
  const recent = [...state.tasks].sort((a, b) => b.progress - a.progress).slice(0, 4)

  return `
    <section class="welcome-card">
      <div>
        <span class="welcome-kicker">${todayGreeting()}, keep up the momentum</span>
        <h2>Move todays important work<br/>to the next milestone.</h2>
        <p>Tasks, requests, and observability data live in one desktop workspace.</p>
        <button class="welcome-button" data-action="navigate" data-page="tasks" data-guance-action-name="View all tasks">
          View all tasks ${icon('arrow', 16)}
        </button>
      </div>
      <div class="orbit-visual" aria-hidden="true">
        <div class="orbit orbit-one"><i></i></div>
        <div class="orbit orbit-two"><i></i></div>
        <div class="orbit-core"><span>${averageProgress}%</span><small>Overall progress</small></div>
      </div>
    </section>

    <section class="metrics-grid">
      ${metricCard('Completed', completed, 'Delivered this cycle', 'check', 'mint')}
      ${metricCard('In Progress', inProgress, 'Actively progressing', 'activity', 'blue')}
      ${metricCard('In Review', review, 'Needs your attention', 'clock', 'amber')}
      ${metricCard('Network requests', state.requestLogs.length, 'Triggered this session', 'wifi', 'violet')}
    </section>

    <section class="dashboard-grid">
      <div class="panel recent-panel">
        <div class="panel-heading">
          <div><span class="section-label">TASK PROGRESS</span><h3>Recent work</h3></div>
          <button class="text-button" data-action="navigate" data-page="tasks">All tasks ${icon('arrow', 14)}</button>
        </div>
        <div class="recent-list">
          ${recent.map(renderRecentTask).join('')}
        </div>
      </div>

      <div class="panel focus-panel">
        <div class="panel-heading">
          <div><span class="section-label">PROJECT DISTRIBUTION</span><h3>Current focus</h3></div>
          <span class="live-pill"><i></i> LIVE</span>
        </div>
        ${renderProjectDistribution()}
        <div class="focus-note">
          <div>${icon('bolt', 18)}</div>
          <p><strong>Suggestion</strong><span>Complete the OrbitDesk experience review, then verify RUM events.</span></p>
        </div>
      </div>
    </section>
  `
}

function metricCard(
  title: string,
  value: number,
  subtitle: string,
  iconName: Parameters<typeof icon>[0],
  tone: string,
): string {
  return `
    <article class="metric-card">
      <div class="metric-icon ${tone}">${icon(iconName, 19)}</div>
      <div><span>${title}</span><strong>${value}</strong><small>${subtitle}</small></div>
    </article>
  `
}

function renderRecentTask(task: WorkspaceTask): string {
  return `
    <button class="recent-task" data-action="open-task" data-task-id="${task.id}">
      <div class="task-project-mark project-${projectTone(task.project)}">${escapeHtml(task.project.slice(0, 1))}</div>
      <div class="recent-task-copy">
        <strong>${escapeHtml(task.title)}</strong>
        <span>${escapeHtml(task.project)} · ${formatDate(task.dueDate)}</span>
      </div>
      <div class="mini-progress"><i style="width:${task.progress}%"></i></div>
      <b>${task.progress}%</b>
      ${icon('arrow', 15)}
    </button>
  `
}

function projectTone(project: string): number {
  return (Array.from(project).reduce((sum, char) => sum + char.charCodeAt(0), 0) % 4) + 1
}

function renderProjectDistribution(): string {
  const counts = new Map<string, number>()
  state.tasks.forEach((task) => counts.set(task.project, (counts.get(task.project) || 0) + 1))
  const entries = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4)
  const max = Math.max(...entries.map((entry) => entry[1]), 1)

  return `
    <div class="project-bars">
      ${entries
        .map(
          ([project, count], index) => `
          <div class="project-bar-row">
            <div><i class="bar-dot tone-${index + 1}"></i><span>${escapeHtml(project)}</span><b>${count}</b></div>
            <div class="project-bar"><i class="tone-${index + 1}" style="width:${Math.max(
              18,
              (count / max) * 100,
            )}%"></i></div>
          </div>
        `,
        )
        .join('')}
    </div>
  `
}

function renderTasks(): string {
  return `
    <section class="task-toolbar">
      <div class="search-field">
        ${icon('search', 17)}
        <input
          id="task-search"
          value="${escapeHtml(state.taskQuery)}"
          placeholder="Search tasks or projects..."
          aria-label="Search tasks"
        />
        <kbd>⌘ K</kbd>
      </div>
      <div class="filter-tabs" role="group" aria-label="Task status filters">
        ${(['All', 'Planned', 'In Progress', 'In Review', 'Completed'] as const)
          .map(
            (status) =>
              `<button class="${state.statusFilter === status ? 'active' : ''}" data-action="filter-status" data-status="${status}">${status}</button>`,
          )
          .join('')}
      </div>
    </section>
    <div id="task-list-region">${renderTaskListRegion()}</div>
  `
}

function filteredTasks(): WorkspaceTask[] {
  const query = state.taskQuery.trim().toLowerCase()
  return state.tasks.filter((task) => {
    const matchesQuery =
      !query ||
      task.title.toLowerCase().includes(query) ||
      task.project.toLowerCase().includes(query) ||
      task.description.toLowerCase().includes(query)
    const matchesStatus = state.statusFilter === 'All' || task.status === state.statusFilter
    return matchesQuery && matchesStatus
  })
}

function renderTaskListRegion(): string {
  const tasks = filteredTasks()
  const selected = state.tasks.find((task) => task.id === state.selectedTaskId)
  return `
    <div class="list-summary">
      <p><strong>${tasks.length}</strong>  tasks<span>Stored on this device</span></p>
      <button class="secondary-button" data-action="open-task-modal">${icon('plus', 16)} Add task</button>
    </div>
    ${
      tasks.length
        ? `<div class="task-grid">${tasks.map(renderTaskCard).join('')}</div>`
        : `<div class="empty-state">${icon('search', 28)}<h3>No matching tasks</h3><p>Try a different search term or status filter.</p></div>`
    }
    ${selected ? renderTaskDrawer(selected) : ''}
  `
}

function renderTaskCard(task: WorkspaceTask): string {
  return `
    <article class="task-card" data-action="open-task" data-task-id="${task.id}">
      <div class="task-card-top">
        <span class="project-chip project-${projectTone(task.project)}">${escapeHtml(task.project)}</span>
        <span class="priority priority-${task.priority}">${task.priority} priority</span>
      </div>
      <h3>${escapeHtml(task.title)}</h3>
      <p>${escapeHtml(task.description)}</p>
      <div class="task-progress-copy"><span>Progress</span><strong>${task.progress}%</strong></div>
      <div class="task-progress"><i style="width:${task.progress}%"></i></div>
      <div class="task-card-footer">
        <div class="avatar small">${escapeHtml(task.owner)}</div>
        <span>${icon('clock', 14)} ${formatDate(task.dueDate)}</span>
        <select class="status-select status-${statusTone(task.status)}" data-role="task-status" data-task-id="${task.id}" aria-label="Change task status">
          ${statusOptions(task.status)}
        </select>
      </div>
    </article>
  `
}

function statusOptions(selected: TaskStatus): string {
  return (['Planned', 'In Progress', 'In Review', 'Completed'] as TaskStatus[])
    .map((status) => `<option value="${status}" ${status === selected ? 'selected' : ''}>${status}</option>`)
    .join('')
}

function statusTone(status: TaskStatus): string {
  return status.toLowerCase().replaceAll(' ', '-')
}

function renderTaskDrawer(task: WorkspaceTask): string {
  return `
    <div class="drawer-backdrop" data-action="close-task"></div>
    <aside class="task-drawer" aria-label="Task details">
      <div class="drawer-header">
        <span class="project-chip project-${projectTone(task.project)}">${escapeHtml(task.project)}</span>
        <button class="icon-button" data-action="close-task" aria-label="Close">${icon('close', 18)}</button>
      </div>
      <h2>${escapeHtml(task.title)}</h2>
      <p class="drawer-description">${escapeHtml(task.description)}</p>
      <dl class="detail-list">
        <div><dt>Status</dt><dd>${escapeHtml(task.status)}</dd></div>
        <div><dt>Priority</dt><dd>${escapeHtml(task.priority)}</dd></div>
        <div><dt>Due date</dt><dd>${formatDate(task.dueDate)}</dd></div>
        <div><dt>Owner</dt><dd>${escapeHtml(task.owner)}</dd></div>
      </dl>
      <div class="drawer-progress">
        <div><span>Progress</span><strong>${task.progress}%</strong></div>
        <div class="task-progress"><i style="width:${task.progress}%"></i></div>
      </div>
      <div class="drawer-actions">
        ${
          task.status === 'Completed'
            ? `<button class="secondary-button" data-action="reopen-task" data-task-id="${task.id}">Reopen</button>`
            : `<button class="primary-button wide" data-action="complete-task" data-task-id="${task.id}">${icon('check', 16)} Mark completed</button>`
        }
        <button class="danger-button" data-action="delete-task" data-task-id="${task.id}">${icon('trash', 16)}</button>
      </div>
    </aside>
  `
}

function renderRequests(): string {
  return `
    <section class="request-hero">
      <div>
        <span class="section-label">NETWORK PLAYGROUND</span>
        <h2>Trigger requests and inspect real Resource events.</h2>
        <p>Each click sends a fetch from the Renderer and is collected as a Guance RUM Resource.</p>
      </div>
      <div class="request-hero-badge">${icon('wifi', 25)}<span><strong>${state.requestLogs.length}</strong>Requests this session</span></div>
    </section>

    <section class="request-card-grid">
      ${requestDefinitions
        .map(
          (request) => `
          <article class="request-card tone-${request.tone}">
            <div class="request-icon">${request.id === 'failure' ? icon('activity', 20) : icon('arrow', 20)}</div>
            <div>
              <h3>${request.label}</h3>
              <p>${request.description}</p>
            </div>
            <button
              class="request-button"
              data-action="run-request"
              data-request-id="${request.id}"
              ${state.requestBusy ? 'disabled' : ''}
              data-guance-action-name="${request.label}"
            >
              ${state.requestBusy === request.id ? '<i class="spinner"></i> Requesting' : `Send request ${icon('arrow', 15)}`}
            </button>
          </article>
        `,
        )
        .join('')}
    </section>

    <section class="request-results-grid">
      <div class="panel response-panel">
        <div class="panel-heading">
          <div><span class="section-label">RESPONSE PREVIEW</span><h3>${escapeHtml(
            state.requestPayloadLabel,
          )}</h3></div>
          <span class="code-pill">JSON</span>
        </div>
        <pre>${escapeHtml(
          state.requestPayload === null
            ? '{\n  "tip": "Choose a request above to begin"\n}'
            : JSON.stringify(state.requestPayload, null, 2),
        )}</pre>
      </div>

      <div class="panel request-log-panel">
        <div class="panel-heading">
          <div><span class="section-label">REQUEST LOG</span><h3>Request log</h3></div>
          <button class="text-button" data-action="clear-request-log" ${state.requestLogs.length ? '' : 'disabled'}>Clear</button>
        </div>
        ${
          state.requestLogs.length
            ? `<div class="request-log-list">${state.requestLogs.map(renderRequestLog).join('')}</div>`
            : `<div class="mini-empty">${icon('activity', 23)}<p>Status and duration appear here after each request.</p></div>`
        }
      </div>
    </section>
  `
}

function renderRequestLog(log: RequestLog): string {
  return `
    <div class="request-log-row">
      <i class="${log.ok ? 'success' : 'failed'}"></i>
      <div><strong>${escapeHtml(log.label)}</strong><span>${escapeHtml(log.url)}</span></div>
      <b class="${log.ok ? 'success' : 'failed'}">${log.status}</b>
      <span>${log.duration} ms</span>
      <time>${escapeHtml(log.time)}</time>
    </div>
  `
}

function renderSettings(): string {
  const statusClass =
    rumState.status === 'active' ? 'success' : rumState.status === 'error' ? 'failed' : 'pending'
  const replayStatus = !rumState.sessionReplay
    ? 'Disabled'
    : isSessionReplayRecording()
      ? 'Recording'
      : 'Configured, waiting for a session'
  return `
    <section class="settings-layout">
      <div class="settings-main">
        <section class="panel settings-section">
          <div class="settings-heading">
            <div class="settings-icon app">${icon('layers', 21)}</div>
            <div><h2>Guance Native SDK</h2><p>Settings mapped by Electron Main to the macOS Adapter</p></div>
            <span class="settings-status success"><i></i>${escapeHtml(appInfo.adapterMode)}</span>
          </div>
          <div class="integration-message success">
            ${icon('check', 18)}
            <span>The Electron Adapter owns the Native SDK lifecycle.</span>
          </div>
          <dl class="settings-table">
            ${settingRow('Application ID', appInfo.nativeSettings?.applicationId || 'Not configured')}
            ${settingRow('Intake mode', appInfo.nativeSettings?.intakeMode || 'Not configured')}
            ${settingRow('Service', appInfo.nativeSettings?.service || 'Not configured')}
            ${settingRow('Environment', appInfo.nativeSettings?.environment || 'Not configured')}
            ${settingRow('RUM sample rate', String(appInfo.nativeSettings?.sampleRate ?? 'Not configured'))}
            ${settingRow('Native Logger', enabledLabel(appInfo.nativeSettings?.loggingEnabled))}
            ${settingRow('Native Tracing', enabledLabel(appInfo.nativeSettings?.traceEnabled))}
            ${settingRow('Native Session Replay', enabledLabel(appInfo.nativeSettings?.replayEnabled))}
          </dl>
        </section>

        <section class="panel settings-section">
          <div class="settings-heading">
            <div class="settings-icon rum">${icon('activity', 21)}</div>
            <div><h2>Guance Web RUM</h2><p>Renderer collection status and runtime configuration</p></div>
            <span class="settings-status ${statusClass}"><i></i>${rumStatusLabel()}</span>
          </div>
          <div class="integration-message ${statusClass}">
            ${icon(rumState.status === 'active' ? 'check' : 'info', 18)}
            <span>${escapeHtml(rumState.message)}</span>
          </div>
          <dl class="settings-table">
            ${settingRow('Application ID', rumState.applicationId)}
            ${settingRow('Transport', rumState.intakeMode)}
            ${settingRow('Service', rumState.service)}
            ${settingRow('Environment', rumState.environment)}
            ${settingRow('Session storage', 'local-storage')}
            ${settingRow('Session Replay', replayStatus)}
            ${settingRow('Browser Logs', enabledLabel(rumState.webLogs))}
          </dl>
          <div class="settings-actions">
            <button class="secondary-button" data-action="send-rum-action" ${rumState.configured ? '' : 'disabled'}>
              ${icon('bolt', 16)} Send test Action
            </button>
            <button class="secondary-button" data-action="send-rum-error" ${rumState.configured ? '' : 'disabled'}>
              ${icon('activity', 16)} Report test Error
            </button>
            <button class="secondary-button" data-action="send-web-log" ${rumState.webLogs ? '' : 'disabled'}>
              ${icon('activity', 16)} Send test Log
            </button>
            <a href="https://docs.guance.com/real-user-monitoring/web/electron-access/" target="_blank" rel="noreferrer">
              View integration docs ${icon('external', 14)}
            </a>
          </div>
        </section>

        <section class="panel settings-section">
          <div class="settings-heading">
            <div class="settings-icon app">${icon('layers', 21)}</div>
            <div><h2>App preferences</h2><p>Local settings stored on this device</p></div>
          </div>
          ${toggleRow('Compact list mode', 'Reduce card spacing to show more information', 'compactMode', state.preferences.compactMode)}
          ${toggleRow('Request completion notifications', 'Show a lightweight status after each request', 'requestSounds', state.preferences.requestSounds)}
        </section>
      </div>

      <aside class="settings-side">
        <section class="panel runtime-card">
          <div class="runtime-logo"><span></span><i></i></div>
          <h3>${escapeHtml(appInfo.name)}</h3>
          <p>Version ${escapeHtml(appInfo.version)}</p>
          <dl>
            <div><dt>Electron</dt><dd>${escapeHtml(appInfo.electronVersion)}</dd></div>
            <div><dt>Chromium</dt><dd>${escapeHtml(appInfo.chromeVersion.split(' ')[0])}</dd></div>
            <div><dt>Platform</dt><dd>${escapeHtml(appInfo.platform)} · ${escapeHtml(appInfo.arch)}</dd></div>
          </dl>
        </section>
        <section class="security-note">
          ${icon('shield', 20)}
          <div><strong>Context isolation enabled</strong><p>contextIsolation: true<br/>nodeIntegration: false<br/>sandbox: false (unbundled demo preload)</p></div>
        </section>
      </aside>
    </section>
  `
}

function settingRow(label: string, value: string): string {
  return `<div><dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value)}</dd></div>`
}

function enabledLabel(value: boolean | undefined): string {
  if (value === undefined) return 'Not configured'
  return value ? 'Enabled' : 'Disabled'
}

function toggleRow(label: string, description: string, key: keyof Preferences, enabled: boolean): string {
  return `
    <div class="toggle-row">
      <div><strong>${label}</strong><span>${description}</span></div>
      <button
        class="toggle ${enabled ? 'active' : ''}"
        role="switch"
        aria-checked="${enabled}"
        data-action="toggle-preference"
        data-preference="${key}"
      ><i></i></button>
    </div>
  `
}

function renderTaskModal(): string {
  return `
    <div class="modal-backdrop" data-action="close-task-modal">
      <section class="modal" role="dialog" aria-modal="true" aria-labelledby="new-task-title">
        <div class="modal-header">
          <div><span class="section-label">NEW TASK</span><h2 id="new-task-title">Create a new task</h2></div>
          <button class="icon-button" data-action="close-task-modal" aria-label="Close">${icon('close', 18)}</button>
        </div>
        <form id="new-task-form">
          <label class="full-field">Task name<input name="title" required maxlength="60" placeholder="For example: verify Guance Resource data" autofocus /></label>
          <div class="form-grid">
            <label>Project<input name="project" required maxlength="30" placeholder="OrbitDesk" /></label>
            <label>Priority
              <select name="priority">
                <option value="High">High</option>
                <option value="Medium" selected>Medium</option>
                <option value="Low">Low</option>
              </select>
            </label>
            <label>Due date<input name="dueDate" type="date" required value="2026-08-05" /></label>
            <label>Owner<input name="owner" maxlength="3" value="HL" required /></label>
          </div>
          <label class="full-field">Description<textarea name="description" rows="3" maxlength="180" placeholder="Add goals, acceptance criteria, or context..."></textarea></label>
          <div class="modal-actions">
            <button type="button" class="secondary-button" data-action="close-task-modal">Cancel</button>
            <button type="submit" class="primary-button">${icon('plus', 16)} Create task</button>
          </div>
        </form>
      </section>
    </div>
  `
}

function updateTaskListRegion(): void {
  const region = document.querySelector<HTMLDivElement>('#task-list-region')
  if (region) region.innerHTML = renderTaskListRegion()
}

function showToast(message: string, tone: 'success' | 'error' | 'neutral' = 'neutral'): void {
  const toast = document.createElement('div')
  toast.className = `toast ${tone}`
  toast.innerHTML = `${icon(tone === 'success' ? 'check' : tone === 'error' ? 'activity' : 'info', 17)}<span>${escapeHtml(
    message,
  )}</span>`
  toastRoot.append(toast)
  requestAnimationFrame(() => toast.classList.add('visible'))
  window.setTimeout(() => {
    toast.classList.remove('visible')
    window.setTimeout(() => toast.remove(), 220)
  }, 2600)
}

function navigate(page: Page): void {
  state.page = page
  state.selectedTaskId = null
  startRumView(pageNames[page])
  trackAction('workspace_navigation', { destination: page })
  renderShell()
}

async function runRequest(requestId: string): Promise<void> {
  const request = requestDefinitions.find((item) => item.id === requestId)
  if (!request || state.requestBusy) return

  state.requestBusy = request.id
  trackAction('api_request_started', { request_name: request.id })
  sendLog('OrbitDesk API request started', {
    request_name: request.id,
    request_method: 'GET',
  })
  renderShell()
  const start = performance.now()

  try {
    const response = await fetch(request.endpoint, {
      method: 'GET',
      headers: { Accept: 'application/json' },
    })
    const payload = (await response.json()) as unknown
    const duration = Math.round(performance.now() - start)
    state.requestPayload = payload
    state.requestPayloadLabel = request.label
    state.requestLogs.unshift({
      id: crypto.randomUUID(),
      label: request.label,
      url: new URL(request.endpoint).pathname,
      status: response.status,
      duration,
      time: new Intl.DateTimeFormat('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(
        new Date(),
      ),
      ok: response.ok,
    })
    trackAction('api_request_completed', {
      request_name: request.id,
      status_code: response.status,
      duration_ms: duration,
    })

    if (!response.ok) {
      sendLog('OrbitDesk API request returned an error response', {
        request_name: request.id,
        status_code: response.status,
        duration_ms: duration,
      }, 'warn')
      reportError(new Error(`Demo API returned HTTP ${response.status}`), {
        request_name: request.id,
        status_code: response.status,
      })
      showToast(`Received the expected HTTP ${response.status}`, 'error')
    } else {
      sendLog('OrbitDesk API request completed', {
        request_name: request.id,
        status_code: response.status,
        duration_ms: duration,
      })
      showToast(`${request.label} completed in ${duration} ms`, 'success')
    }
  } catch (error) {
    const duration = Math.round(performance.now() - start)
    const normalizedError = error instanceof Error ? error : new Error('Unknown network error')
    state.requestPayload = { error: normalizedError.message }
    state.requestPayloadLabel = `${request.label} failed`
    state.requestLogs.unshift({
      id: crypto.randomUUID(),
      label: request.label,
      url: new URL(request.endpoint).pathname,
      status: 'ERR',
      duration,
      time: new Intl.DateTimeFormat('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(
        new Date(),
      ),
      ok: false,
    })
    sendLog('OrbitDesk API request failed', {
      request_name: request.id,
      duration_ms: duration,
    }, 'error', normalizedError)
    reportError(normalizedError, { request_name: request.id })
    showToast(normalizedError.message, 'error')
  } finally {
    state.requestBusy = null
    state.requestLogs = state.requestLogs.slice(0, 12)
    renderShell()
  }
}

root.addEventListener('click', (event) => {
  const element = (event.target as HTMLElement).closest<HTMLElement>('[data-action]')
  if (!element) return

  const action = element.dataset.action
  if (action === 'navigate') {
    navigate(element.dataset.page as Page)
  } else if (action === 'open-auxiliary-window') {
    trackAction('open_auxiliary_window')
    void window.orbitDesk?.openAuxiliaryWindow().then(({ webContentsID }) => {
      sendLog('OrbitDesk auxiliary window opened', {
        web_contents_id: webContentsID,
      })
      showToast(`Opened an auxiliary window (WebContents ${webContentsID})`, 'success')
    }).catch((error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not open the H5 window'
      const normalizedError = error instanceof Error ? error : new Error(message)
      sendLog('OrbitDesk auxiliary window failed to open', {
        action: 'open_auxiliary_window',
      }, 'error', normalizedError)
      reportError(normalizedError, { action: 'open_auxiliary_window' })
      showToast(message, 'error')
    })
  } else if (action === 'open-settings') {
    navigate('settings')
  } else if (action === 'open-task-modal') {
    state.modalOpen = true
    renderShell()
  } else if (action === 'close-task-modal') {
    if (event.target === element || element.tagName === 'BUTTON') {
      state.modalOpen = false
      renderShell()
    }
  } else if (action === 'filter-status') {
    state.statusFilter = element.dataset.status as TaskStatus | 'All'
    trackAction('task_filter_changed', { selected_status: state.statusFilter })
    renderShell()
  } else if (action === 'open-task') {
    state.selectedTaskId = element.dataset.taskId || null
    if (state.page !== 'tasks') {
      state.page = 'tasks'
    }
    renderShell()
  } else if (action === 'close-task') {
    state.selectedTaskId = null
    updateTaskListRegion()
  } else if (action === 'complete-task' || action === 'reopen-task') {
    const task = state.tasks.find((item) => item.id === element.dataset.taskId)
    if (task) {
      task.status = action === 'complete-task' ? 'Completed' : 'In Progress'
      task.progress = action === 'complete-task' ? 100 : 70
      saveTasks()
      trackAction('task_status_changed', { task_id: task.id, task_status: task.status })
      sendLog('OrbitDesk task status changed', {
        task_id: task.id,
        task_status: task.status,
      })
      showToast(action === 'complete-task' ? 'Task completed' : 'Task reopened', 'success')
      renderShell()
    }
  } else if (action === 'delete-task') {
    const task = state.tasks.find((item) => item.id === element.dataset.taskId)
    if (task && window.confirm(`Delete "${task.title}"?`)) {
      state.tasks = state.tasks.filter((item) => item.id !== task.id)
      state.selectedTaskId = null
      saveTasks()
      trackAction('task_deleted', { task_id: task.id })
      sendLog('OrbitDesk task deleted', { task_id: task.id }, 'warn')
      showToast('Task deleted')
      renderShell()
    }
  } else if (action === 'run-request') {
    void runRequest(element.dataset.requestId || '')
  } else if (action === 'clear-request-log') {
    state.requestLogs = []
    state.requestPayload = null
    state.requestPayloadLabel = 'No request sent yet'
    renderShell()
  } else if (action === 'toggle-preference') {
    const preference = element.dataset.preference as keyof Preferences
    state.preferences[preference] = !state.preferences[preference]
    savePreferences()
    trackAction('preference_changed', { preference, enabled: state.preferences[preference] })
    renderShell()
  } else if (action === 'send-rum-action') {
    trackAction('manual_rum_test', { source: 'settings', app_version: appInfo.version })
    showToast('The test Action was added to the RUM queue', 'success')
  } else if (action === 'send-rum-error') {
    reportError(new Error('OrbitDesk manual test error'), { source: 'settings_test' })
    showToast('The test Error was added to the RUM queue', 'success')
  } else if (action === 'send-web-log') {
    sendLog('OrbitDesk manual Browser Log', {
      source: 'settings_test',
      app_version: appInfo.version,
    })
    showToast('The test Log was sent through the Native SDK bridge', 'success')
  }
})

root.addEventListener('input', (event) => {
  const input = event.target as HTMLInputElement
  if (input.id === 'task-search') {
    state.taskQuery = input.value
    updateTaskListRegion()
  }
})

root.addEventListener('change', (event) => {
  const select = (event.target as HTMLElement).closest<HTMLSelectElement>('[data-role="task-status"]')
  if (!select) return

  const task = state.tasks.find((item) => item.id === select.dataset.taskId)
  if (!task) return

  task.status = select.value as TaskStatus
  if (task.status === 'Completed') task.progress = 100
  if (task.status === 'Planned' && task.progress === 100) task.progress = 10
  saveTasks()
  trackAction('task_status_changed', { task_id: task.id, task_status: task.status })
  showToast(`Task status updated to "${task.status}"`, 'success')
  renderShell()
})

root.addEventListener('submit', (event) => {
  if (!(event.target instanceof HTMLFormElement) || event.target.id !== 'new-task-form') return
  event.preventDefault()

  const formData = new FormData(event.target)
  const task: WorkspaceTask = {
    id: crypto.randomUUID(),
    title: String(formData.get('title') || '').trim(),
    project: String(formData.get('project') || '').trim(),
    description: String(formData.get('description') || '').trim() || 'No additional description.',
    status: 'Planned',
    priority: String(formData.get('priority')) as TaskPriority,
    dueDate: String(formData.get('dueDate')),
    progress: 0,
    owner: String(formData.get('owner') || 'HL').trim().toUpperCase(),
  }

  state.tasks.unshift(task)
  state.modalOpen = false
  state.page = 'tasks'
  state.statusFilter = 'All'
  saveTasks()
  trackAction('task_created', {
    task_id: task.id,
    project_name: task.project,
    task_priority: task.priority,
  })
  sendLog('OrbitDesk task created', {
    task_id: task.id,
    project_name: task.project,
    task_priority: task.priority,
  })
  showToast('Task created', 'success')
  renderShell()
})

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    if (state.modalOpen) {
      state.modalOpen = false
      renderShell()
    } else if (state.selectedTaskId) {
      state.selectedTaskId = null
      updateTaskListRegion()
    }
  }

  if (event.metaKey && event.key.toLowerCase() === 'k') {
    event.preventDefault()
    if (state.page !== 'tasks') {
      navigate('tasks')
    }
    window.setTimeout(() => document.querySelector<HTMLInputElement>('#task-search')?.focus(), 0)
  }
})

async function bootstrap(): Promise<void> {
  try {
    if (window.orbitDesk) {
      appInfo = await window.orbitDesk.getAppInfo()
    }
  } catch (error) {
    console.warn('Could not read Electron runtime information', error)
  }

  rumState = initializeRum(appInfo)
  renderShell()
  window.orbitDesk?.rendererReady(rumState.status === 'active' ? 'active' : 'error')
}

void bootstrap()
