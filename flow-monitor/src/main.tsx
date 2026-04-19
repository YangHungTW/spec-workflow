import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./styles/theme.css";
import { applyThemeToDocument } from "./stores/themeStore";
import type { Theme } from "./stores/themeStore";

// First-paint theme application — runs synchronously BEFORE ReactDOM.createRoot
// to prevent flash of unstyled content (FOUC) when the user has chosen dark mode.
// Reads persisted theme from localStorage (set by themeStore on each toggle);
// defaults to "light" on first run (AC15.c).
//
// We use localStorage here rather than an IPC round-trip because IPC is async
// and would force an await before render; localStorage is synchronous.
// The authoritative source is the Tauri settings file; localStorage acts as a
// fast-path cache written by useTheme() on every change.
const _savedTheme = localStorage.getItem("theme") as Theme | null;
const _initialTheme: Theme =
  _savedTheme === "dark" || _savedTheme === "light" ? _savedTheme : "light";
applyThemeToDocument(_initialTheme);

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
