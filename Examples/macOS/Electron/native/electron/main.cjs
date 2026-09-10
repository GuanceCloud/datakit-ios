"use strict";

const { app, BrowserWindow, ipcMain, Menu, shell } = require("electron");
const electron = require("electron");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { bootstrap } = require("@cloudcare/electron-native-adapter");

const isDevelopment = Boolean(process.env.VITE_DEV_SERVER_URL);
const smoke = process.env.GUANCE_EXAMPLE_SMOKE === "1";
const projectRoot = path.resolve(__dirname, "..");
let client;
let mainWindow;
let stopping = false;
let exitCode = 0;
let smokeTimer;
const replayStates = new Map();

app.setName("OrbitDesk External Electron");
if (process.platform === "darwin") app.setActivationPolicy("accessory");

function rendererURL(surface) {
  const url = isDevelopment
    ? new URL(process.env.VITE_DEV_SERVER_URL)
    : pathToFileURL(path.join(projectRoot, "dist", "index.html"));
  url.searchParams.set("surface", surface);
  return url.toString();
}

function createWindow(surface = "dashboard") {
  const popup = surface === "popup";
  const window = new BrowserWindow({
    width: popup ? 820 : 1120,
    height: popup ? 650 : 820,
    minWidth: popup ? 680 : 900,
    minHeight: popup ? 520 : 680,
    show: false,
    title: popup ? "OrbitDesk · Electron Customer Details" : "OrbitDesk · External Mode",
    titleBarStyle: "hiddenInset",
    backgroundColor: "#f7f6f2",
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });
  const webContentsId = window.webContents.id;

  if (!popup) mainWindow = window;
  window.once("ready-to-show", () => window.show());
  window.once("closed", () => {
    replayStates.delete(webContentsId);
    if (mainWindow === window) mainWindow = undefined;
  });
  window.webContents.on("did-fail-load", (_event, code, description, url) => {
    console.error("[external-example] Renderer load failed", { code, description, url });
  });
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("https://")) void shell.openExternal(url);
    return { action: "deny" };
  });
  void window.loadURL(rendererURL(surface));
  return window;
}

function createPopup() {
  const existing = BrowserWindow.getAllWindows().find((window) => window.__orbitdeskPopup === true);
  if (existing) {
    existing.show();
    existing.focus();
    return existing;
  }
  const window = createWindow("popup");
  window.__orbitdeskPopup = true;
  return window;
}

function createMenu() {
  if (process.platform === "darwin") {
    app.dock.hide();
    Menu.setApplicationMenu(null);
    return;
  }
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    { label: "OrbitDesk", submenu: [{ role: "about" }, { type: "separator" }, { role: "quit" }] },
    { label: "Window", submenu: [{ role: "minimize" }, { role: "front" }] },
  ]));
}

ipcMain.handle("native-host:get-info", (event) => ({
  electronVersion: process.versions.electron,
  platform: process.platform,
  arch: process.arch,
  surface: event.sender.getURL().includes("surface=popup") ? "popup" : "dashboard",
  adapterMode: client?.mode || "external",
  capabilities: client?.capabilities,
}));
ipcMain.handle("native-host:open-popup", () => { createPopup(); });
ipcMain.on("native-host:set-replay-recording", (event, recording) => {
  replayStates.set(event.sender.id, recording === true);
});
ipcMain.on("native-host:renderer-ready", (_event, rumStatus) => {
  console.info("[external-example] Renderer and Native adapter ready");
  if (smoke) {
    if (rumStatus !== "active") {
      exitCode = 1;
      console.error("[external-example] Web RUM did not connect to the Native SDK bridge");
    }
    setTimeout(() => app.quit(), 500);
  }
});

app.whenReady().then(async () => {
  if (process.platform !== "darwin") throw new Error("This example requires macOS.");
  client = await bootstrap({
    electron,
    native: { mode: "external" },
    autoAttach: true,
    onError: (error) => console.error("[external-example] adapter error", error),
  });
  console.info("[external-example] external mode connected");
  createMenu();
  createWindow();
  if (smoke) {
    smokeTimer = setTimeout(() => {
      exitCode = 1;
      console.error("[external-example] smoke test timed out");
      app.quit();
    }, 20_000);
  }
}).catch((error) => {
  console.error("[external-example] startup failed", error);
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
      console.error("[external-example] adapter shutdown failed", error);
    })
    .finally(() => app.exit(exitCode));
});

process.once("SIGTERM", () => app.quit());
process.once("SIGINT", () => app.quit());
app.on("window-all-closed", () => app.quit());
