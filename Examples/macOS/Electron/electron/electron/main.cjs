"use strict";

const path = require("node:path");
const { pathToFileURL } = require("node:url");
const electron = require("electron");
const { app, BrowserWindow, ipcMain, Menu, shell } = electron;
const { bootstrap } = require("@cloudcare/electron-native-adapter");

const projectRoot = path.resolve(__dirname, "..");
const isDevelopment = Boolean(process.env.VITE_DEV_SERVER_URL);
const smoke = process.env.GUANCE_EXAMPLE_SMOKE === "1";
let client;
let activeNativeSettings;
let stopping = false;
let exitCode = 0;
let smokeTimer;

app.setName("OrbitDesk Managed");

function value(...keys) {
  for (const key of keys) {
    const candidate = process.env[key]?.trim();
    if (candidate) return candidate;
  }
  return "";
}

function boolean(key, fallback) {
  const candidate = value(key).toLowerCase();
  return candidate ? !["0", "false", "no", "off"].includes(candidate) : fallback;
}

function rate(key, fallback) {
  const candidate = Number.parseFloat(value(key));
  if (!Number.isFinite(candidate)) return fallback;
  return Math.min(1, Math.max(0, candidate));
}

function nativeRuntimeDirectory() {
  if (app.isPackaged) return path.join(process.resourcesPath, "native");
  return value("GUANCE_NATIVE_RUNTIME") ||
    path.join(projectRoot, ".cloudcare/native/darwin/runtime");
}

function nativeSettings() {
  return {
    applicationId: value("GUANCE_NATIVE_APP_ID", "VITE_GUANCE_APPLICATION_ID"),
    datakitUrl: value("GUANCE_NATIVE_DATAKIT_URL", "VITE_GUANCE_DATAKIT_ORIGIN"),
    datawayUrl: value("GUANCE_NATIVE_DATAWAY_URL", "VITE_GUANCE_SITE"),
    clientToken: value("GUANCE_NATIVE_CLIENT_TOKEN", "VITE_GUANCE_CLIENT_TOKEN"),
    service: value("GUANCE_NATIVE_SERVICE", "VITE_GUANCE_SERVICE") || "orbitdesk-managed-native",
    environment: value("GUANCE_NATIVE_ENV", "VITE_GUANCE_ENV") || "development",
    version: app.getVersion(),
    sampleRate: rate("GUANCE_NATIVE_SAMPLE_RATE", 1),
    loggingEnabled: boolean("GUANCE_NATIVE_LOGGING", true),
    loggingSampleRate: rate("GUANCE_NATIVE_LOGGING_SAMPLE_RATE", 1),
    replayEnabled: boolean("GUANCE_NATIVE_SESSION_REPLAY", true),
    replaySampleRate: rate("GUANCE_NATIVE_SESSION_REPLAY_SAMPLE_RATE", 1),
    replayPrivacy: value("GUANCE_NATIVE_REPLAY_PRIVACY") || "mask-user-input",
    traceEnabled: boolean("GUANCE_NATIVE_TRACE", true),
    traceSampleRate: rate("GUANCE_NATIVE_TRACE_SAMPLE_RATE", 1),
    traceType: value("GUANCE_NATIVE_TRACE_TYPE") || "ddtrace",
    traceAllowedUrls: value("GUANCE_NATIVE_TRACE_ALLOWED_URLS", "VITE_GUANCE_ALLOWED_TRACING_URL"),
    debug: boolean("GUANCE_NATIVE_DEBUG", true),
  };
}

function rendererURL(surface) {
  const url = isDevelopment
    ? new URL(process.env.VITE_DEV_SERVER_URL)
    : pathToFileURL(path.join(projectRoot, "dist/index.html"));
  if (surface !== "dashboard") url.searchParams.set("surface", surface);
  return url.toString();
}

function createWindow(surface = "dashboard", parent) {
  const popup = surface === "requests";
  const window = new BrowserWindow({
    width: popup ? 920 : 1220,
    height: popup ? 680 : 820,
    minWidth: popup ? 720 : 980,
    minHeight: popup ? 520 : 680,
    parent: parent && !parent.isDestroyed() ? parent : undefined,
    show: false,
    title: popup ? "OrbitDesk · Request Lab" : "OrbitDesk · Managed Mode",
    titleBarStyle: "hiddenInset",
    trafficLightPosition: { x: 18, y: 18 },
    backgroundColor: "#f6f5f2",
    vibrancy: "under-window",
    visualEffectState: "active",
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });
  client?.attachWindow(window);
  window.once("ready-to-show", () => window.show());
  window.webContents.on("did-fail-load", (_event, code, description, url) => {
    console.error("[managed-example] Renderer load failed", { code, description, url });
  });
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("https://")) void shell.openExternal(url);
    return { action: "deny" };
  });
  void window.loadURL(rendererURL(surface));
  return window;
}

function createMenu() {
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {
      label: "OrbitDesk",
      submenu: [
        { role: "about" },
        { type: "separator" },
        { role: "hide" },
        { role: "hideOthers" },
        { role: "unhide" },
        { type: "separator" },
        { role: "quit" },
      ],
    },
    { label: "Edit", submenu: [{ role: "undo" }, { role: "redo" }, { type: "separator" }, { role: "cut" }, { role: "copy" }, { role: "paste" }, { role: "selectAll" }] },
    { label: "View", submenu: [{ role: "reload" }, { role: "toggleDevTools" }, { type: "separator" }, { role: "resetZoom" }, { role: "zoomIn" }, { role: "zoomOut" }] },
    { label: "Window", submenu: [{ role: "minimize" }, { role: "zoom" }, { role: "front" }] },
  ]));
}

ipcMain.handle("app:get-info", () => ({
  name: app.getName(),
  version: app.getVersion(),
  electronVersion: process.versions.electron,
  chromeVersion: process.versions.chrome,
  platform: process.platform,
  arch: process.arch,
  adapterMode: client?.mode || "managed",
  capabilities: client?.capabilities,
  nativeSettings: activeNativeSettings
    ? {
        applicationId: activeNativeSettings.applicationId,
        intakeMode: activeNativeSettings.datakitUrl ? "DataKit" : "DataWay",
        service: activeNativeSettings.service,
        environment: activeNativeSettings.environment,
        sampleRate: activeNativeSettings.sampleRate,
        loggingEnabled: activeNativeSettings.loggingEnabled,
        replayEnabled: activeNativeSettings.replayEnabled,
        traceEnabled: activeNativeSettings.traceEnabled,
      }
    : undefined,
}));

ipcMain.handle("app:open-auxiliary-window", (event) => {
  const window = createWindow("requests", BrowserWindow.fromWebContents(event.sender));
  return { webContentsID: window.webContents.id };
});

ipcMain.on("app:renderer-ready", (_event, rumStatus) => {
  console.info("[managed-example] Renderer and Native adapter ready");
  if (smoke) {
    if (rumStatus !== "active") {
      exitCode = 1;
      console.error("[managed-example] Web RUM did not connect to the Native SDK bridge");
    }
    setTimeout(() => app.quit(), 500);
  }
});

app.whenReady().then(async () => {
  if (process.platform !== "darwin") throw new Error("This example requires macOS.");
  const settings = nativeSettings();
  activeNativeSettings = settings;
  client = await bootstrap({
    electron,
    native: {
      mode: "managed",
      directory: nativeRuntimeDirectory(),
      settings,
    },
    autoAttach: true,
    onError: (error) => console.error("[managed-example] adapter error", error),
  });
  console.info("[managed-example] managed mode connected");
  createMenu();
  createWindow();
  if (smoke) {
    smokeTimer = setTimeout(() => {
      exitCode = 1;
      console.error("[managed-example] smoke test timed out");
      app.quit();
    }, 20_000);
  }
}).catch((error) => {
  console.error("[managed-example] startup failed", error);
  app.exit(1);
});

app.on("before-quit", (event) => {
  if (stopping || !client) return;
  event.preventDefault();
  stopping = true;
  clearTimeout(smokeTimer);
  const activeClient = client;
  client = undefined;
  Promise.resolve(activeClient.stop())
    .catch((error) => {
      exitCode = 1;
      console.error("[managed-example] adapter shutdown failed", error);
    })
    .finally(() => app.exit(exitCode));
});

app.on("window-all-closed", () => app.quit());
process.once("SIGTERM", () => app.quit());
process.once("SIGINT", () => app.quit());
