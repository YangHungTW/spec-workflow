/**
 * Theme store — manages light/dark theme via CSS html.dark class.
 *
 * Design decisions:
 *   - Theme is persisted via Tauri IPC (get_settings / save_settings).
 *   - The html.dark class is applied synchronously before React mounts
 *     (first-paint path in main.tsx) to avoid flash of unstyled content.
 *   - No OS appearance auto-follow — user-only toggle per B1 carve-out;
 *     OS auto-follow is deferred to B2.
 *   - setTheme / toggleTheme update the class synchronously within one frame.
 */

import { useState, useEffect, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";

export type Theme = "light" | "dark";

/** Settings shape returned by the get_settings IPC command. */
interface SettingsPayload {
  theme?: Theme;
}

/**
 * Apply a theme to the document root synchronously.
 * Called from main.tsx before ReactDOM.createRoot to avoid FOUC,
 * and from the hook to flip within one frame.
 */
/**
 * Write theme to localStorage (fast-path cache for first-paint in main.tsx).
 * Guards against environments where localStorage is unavailable (e.g. test
 * runners that disable storage, or server-side rendering contexts).
 */
function persistTheme(theme: Theme): void {
  try {
    if (typeof globalThis.localStorage !== "undefined") {
      globalThis.localStorage.setItem("theme", theme);
    }
  } catch {
    // Storage quota exceeded or blocked — silently skip; IPC is authoritative.
  }
}

export function applyThemeToDocument(theme: Theme): void {
  if (theme === "dark") {
    document.documentElement.classList.add("dark");
  } else {
    document.documentElement.classList.remove("dark");
  }
}

/**
 * React hook — exposes current theme, setTheme, and toggleTheme.
 * Loads the persisted theme from IPC on mount; falls back to "light".
 */
export function useTheme(): {
  theme: Theme;
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
} {
  const [theme, setThemeState] = useState<Theme>("light");

  // Load persisted theme from Tauri settings on mount
  useEffect(() => {
    invoke<SettingsPayload>("get_settings")
      .then((settings) => {
        const persisted: Theme = settings.theme === "dark" ? "dark" : "light";
        applyThemeToDocument(persisted);
        setThemeState(persisted);
      })
      .catch(() => {
        // IPC unavailable (e.g. test environment stub returns rejection) —
        // fall back to light and leave the class unchanged.
        applyThemeToDocument("light");
        setThemeState("light");
      });
  }, []);

  const setTheme = useCallback((t: Theme) => {
    applyThemeToDocument(t);
    setThemeState(t);
    // Cache in localStorage for the synchronous first-paint path in main.tsx
    persistTheme(t);
    // Persist to Tauri settings asynchronously; ignore errors (best-effort)
    invoke("save_settings", { theme: t }).catch(() => undefined);
  }, []);

  const toggleTheme = useCallback(() => {
    setThemeState((prev) => {
      const next: Theme = prev === "light" ? "dark" : "light";
      applyThemeToDocument(next);
      persistTheme(next);
      invoke("save_settings", { theme: next }).catch(() => undefined);
      return next;
    });
  }, []);

  return { theme, setTheme, toggleTheme };
}
