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

export type Theme = "light" | "dark";

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
/** Read theme from localStorage (same cache main.tsx uses for first-paint). */
function readPersistedTheme(): Theme {
  try {
    if (typeof globalThis.localStorage !== "undefined") {
      const v = globalThis.localStorage.getItem("theme");
      if (v === "dark" || v === "light") return v;
    }
  } catch {
    // Storage unavailable — silently default
  }
  return "light";
}

export function useTheme(): {
  theme: Theme;
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
} {
  // Initial state reads from localStorage so remounts (e.g. CardDetail navigation)
  // preserve the theme user selected. main.tsx already applied the class before
  // first paint, so no flash even if applyThemeToDocument below is a no-op.
  const [theme, setThemeState] = useState<Theme>(() => readPersistedTheme());

  // Re-apply class on mount defensively — cheap no-op if class already matches.
  useEffect(() => {
    applyThemeToDocument(theme);
  }, [theme]);

  const setTheme = useCallback((t: Theme) => {
    applyThemeToDocument(t);
    setThemeState(t);
    persistTheme(t);
  }, []);

  const toggleTheme = useCallback(() => {
    setThemeState((prev) => {
      const next: Theme = prev === "light" ? "dark" : "light";
      applyThemeToDocument(next);
      persistTheme(next);
      return next;
    });
  }, []);

  return { theme, setTheme, toggleTheme };
}
