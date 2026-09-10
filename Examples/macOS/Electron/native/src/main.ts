import './styles.css'
import { initializeWebRUM, reportError, sendLog, trackAction } from './rum'

const app = document.querySelector<HTMLDivElement>('#app')!
const surface = new URLSearchParams(location.search).get('surface') || 'dashboard'

const pageCopy: Record<string, { eyebrow: string; title: string; description: string }> = {
  dashboard: {
    eyebrow: 'ELECTRON BUSINESS SURFACE',
    title: 'Operations Dashboard',
    description: 'Electron WebContents renders this surface while AppKit owns the outer window and lifecycle.',
  },
  tasks: {
    eyebrow: 'MIGRATED ELECTRON PAGE',
    title: 'Team Tasks',
    description: 'Each WebContents keeps a stable slotId while navigation preserves its container identity.',
  },
  requests: {
    eyebrow: 'RESOURCE & TRACE LAB',
    title: 'Request Lab',
    description: 'These real fetch requests are automatically collected as Resources by the Web SDK.',
  },
  popup: {
    eyebrow: 'ELECTRON AUXILIARY WINDOW',
    title: 'Customer Details',
    description: 'This popup is a separate BrowserWindow with its own WebContents registration and replay slot.',
  },
}

const copy = pageCopy[surface] || pageCopy.dashboard

app.innerHTML = `
  <main class="page">
    <header class="hero">
      <div>
        <p class="eyebrow">${copy.eyebrow}</p>
        <h1>${copy.title}</h1>
        <p class="hero-copy">${copy.description}</p>
      </div>
      <div class="runtime-pill"><span></span> Electron 43 · External Adapter</div>
    </header>
    <section id="surface-content"></section>
  </main>
`

const content = document.querySelector<HTMLElement>('#surface-content')!

if (surface === 'dashboard') renderDashboard(content)
else if (surface === 'tasks') renderTasks(content)
else if (surface === 'requests') renderRequests(content)
else renderPopup(content)

const nativeHost = window.nativeHost
if (nativeHost) {
  void nativeHost.getInfo()
    .then((info) => nativeHost.rendererReady(initializeWebRUM(info)))
    .catch((error) => {
      console.error('[Guance Web RUM] initialization failed', error)
      nativeHost.rendererReady('error')
    })
}

function renderDashboard(root: HTMLElement): void {
  root.innerHTML = `
    <div class="metric-grid">
      ${metric('Requests today', '1,248', '+18%', 'coral')}
      ${metric('Active sessions', '386', '+9%', 'indigo')}
      ${metric('Task completion', '92.4%', '+4.1%', 'mint')}
    </div>
    <div class="content-grid">
      <article class="card activity-card">
        <div class="card-heading"><div><p class="kicker">LIVE ACTIVITY</p><h2>Recent Activity</h2></div><button id="refresh-feed" class="soft-button">Refresh</button></div>
        <div class="activity-list">
          ${activity('Casey', 'Completed macOS Session Replay validation', '2 minutes ago', 'CA')}
          ${activity('Morgan', 'Updated the Electron migration plan', '18 minutes ago', 'MO')}
          ${activity('Jordan', 'Created a request tracing experiment', '43 minutes ago', 'JO')}
        </div>
      </article>
      <article class="card focus-card">
        <p class="kicker">NATIVE + ELECTRON</p><h2>Migration Progress</h2>
        <div class="ring"><strong>68%</strong><span>Pages migrated</span></div>
        <button id="open-popup" class="primary-button">Open Electron Customer Popup</button>
      </article>
    </div>
  `
  root.querySelector('#refresh-feed')?.addEventListener('click', () => {
    trackAction('Refresh recent activity')
    sendLog('OrbitDesk activity feed refreshed', { surface: 'dashboard' })
    const button = root.querySelector<HTMLButtonElement>('#refresh-feed')!
    button.textContent = 'Refreshed'
    window.setTimeout(() => { button.textContent = 'Refresh' }, 1200)
  })
  root.querySelector('#open-popup')?.addEventListener('click', () => {
    trackAction('Open Electron customer popup')
    sendLog('OrbitDesk customer popup requested', { surface: 'dashboard' })
    void window.nativeHost?.openPopup()
  })
}

function renderTasks(root: HTMLElement): void {
  const tasks = [
    ['Verify multi-WebContents slotId', 'Replay', 'Today'],
    ['Inspect Native container fields', 'RUM', 'Tomorrow'],
    ['Document Electron 43 compatibility', 'Docs', 'Friday'],
    ['Regression-test popup Session Replay', 'QA', 'Next Monday'],
  ]
  root.innerHTML = `
    <article class="card task-card">
      <div class="card-heading"><div><p class="kicker">SPRINT 08</p><h2>Current Tasks</h2></div><button id="add-task" class="primary-button compact">Add Task</button></div>
      <div class="task-list">${tasks.map((item, index) => `
        <label class="task-row">
          <input type="checkbox" data-task="${index}" />
          <span class="checkmark"></span>
          <span class="task-title">${item[0]}</span>
          <span class="tag">${item[1]}</span>
          <span class="due">${item[2]}</span>
        </label>`).join('')}</div>
    </article>
  `
  root.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((input) => {
    input.addEventListener('change', () => trackAction('Toggle task status', {
      task_index: input.dataset.task,
      completed: input.checked,
    }))
  })
  root.querySelector('#add-task')?.addEventListener('click', () => {
    trackAction('Add migration task')
    window.alert('Demo task created. Web RUM will collect this interaction.')
  })
}

function renderRequests(root: HTMLElement): void {
  root.innerHTML = `
    <div class="content-grid request-grid">
      <article class="card">
        <p class="kicker">REAL FETCH</p><h2>Send a Business Request</h2>
        <label class="field"><span>Request URL</span><input id="request-url" value="https://dummyjson.com/test" /></label>
        <div class="button-row">
          <button id="send-request" class="primary-button">Send Request</button>
          <button id="report-error" class="soft-button">Report Error</button>
          <button id="send-log" class="soft-button">Send Web Log</button>
        </div>
      </article>
      <article class="card response-card">
        <div class="card-heading"><div><p class="kicker">RESPONSE</p><h2>Response</h2></div><span id="request-status" class="status idle">Waiting</span></div>
        <pre id="response-body">Send a request to inspect the real response.</pre>
      </article>
    </div>
  `
  root.querySelector('#send-request')?.addEventListener('click', async () => {
    const url = root.querySelector<HTMLInputElement>('#request-url')!.value.trim()
    const status = root.querySelector<HTMLElement>('#request-status')!
    const body = root.querySelector<HTMLElement>('#response-body')!
    status.className = 'status loading'
    status.textContent = 'Requesting'
    trackAction('Send real fetch', { url })
    sendLog('OrbitDesk business request started', {
      surface: 'requests',
      request_method: 'GET',
    })
    try {
      const response = await fetch(url)
      const text = await response.text()
      status.className = `status ${response.ok ? 'success' : 'failure'}`
      status.textContent = `${response.status} ${response.statusText}`
      body.textContent = text.slice(0, 1600)
      sendLog(
        response.ok
          ? 'OrbitDesk business request completed'
          : 'OrbitDesk business request returned an error response',
        {
          surface: 'requests',
          status_code: response.status,
        },
        response.ok ? 'info' : 'warn',
      )
    } catch (error) {
      const normalizedError = error instanceof Error ? error : new Error(String(error))
      status.className = 'status failure'
      status.textContent = 'Request failed'
      body.textContent = normalizedError.message
      sendLog('OrbitDesk business request failed', {
        surface: 'requests',
      }, 'error', normalizedError)
      reportError(normalizedError, { url })
    }
  })
  root.querySelector('#report-error')?.addEventListener('click', () => {
    const error = new Error('OrbitDesk Electron Request Lab test error')
    reportError(error, { surface: 'requests', source: 'manual_button' })
    root.querySelector<HTMLElement>('#response-body')!.textContent = 'The test error was sent to the Web SDK.'
  })
  root.querySelector('#send-log')?.addEventListener('click', () => {
    const sent = sendLog('OrbitDesk external-mode Browser Log', {
      surface: 'requests',
      source: 'manual_button',
    })
    root.querySelector<HTMLElement>('#response-body')!.textContent = sent
      ? 'The test log was sent through the Native SDK bridge.'
      : 'Native Browser Logs are disabled.'
  })
}

function renderPopup(root: HTMLElement): void {
  root.innerHTML = `
    <article class="card profile-card">
      <div class="avatar large">AM</div><div><p class="kicker">ENTERPRISE CUSTOMER</p><h2>Acme Mobility</h2><p class="muted">Active across macOS, Windows, and Web</p></div>
      <dl><div><dt>Sessions this month</dt><dd>18,642</dd></div><div><dt>Error rate</dt><dd>0.18%</dd></div><div><dt>Health score</dt><dd>96 / 100</dd></div></dl>
      <button id="popup-action" class="primary-button">Record Customer Follow-up</button>
    </article>
  `
  root.querySelector('#popup-action')?.addEventListener('click', () => {
    trackAction('Record customer follow-up', { customer: 'Acme Mobility' })
    sendLog('OrbitDesk customer follow-up recorded', {
      surface: 'popup',
      customer: 'Acme Mobility',
    })
    const button = root.querySelector<HTMLButtonElement>('#popup-action')!
    button.textContent = 'Recorded'
    button.disabled = true
  })
}

function metric(label: string, value: string, delta: string, color: string): string {
  return `<article class="metric ${color}"><span>${label}</span><strong>${value}</strong><small>${delta} vs. yesterday</small></article>`
}

function activity(name: string, text: string, time: string, initials: string): string {
  return `<div class="activity"><div class="avatar">${initials}</div><div><strong>${name}</strong><p>${text}</p></div><time>${time}</time></div>`
}
