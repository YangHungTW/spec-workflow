import { useState, useEffect } from "react";
import { Route, Routes } from "react-router-dom";
import MainWindow from "./views/MainWindow";
import CardDetail from "./views/CardDetail";
import Settings from "./views/Settings";
import CompactPanel from "./views/CompactPanel";
import { I18nProvider } from "./i18n";
import { CommandPalette } from "./components/CommandPalette";
import { PreflightToast } from "./components/PreflightToast";
import { useInvokeStore } from "./stores/invokeStore";

function ThemeProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function SettingsProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function SessionsProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function App() {
  const [paletteOpen, setPaletteOpen] = useState(false);

  // invokeStore subscribes to in_flight_changed and audit_appended internally
  // (T110). We call it once here at the App root so the subscription is
  // established for the lifetime of the window. Child components that need
  // invokeStore state should call useInvokeStore() independently — each call
  // creates its own subscription, which is acceptable because the Tauri event
  // bridge is efficient (no per-listener poll); we do NOT pass the store down
  // via props to avoid prop-drilling across the deep component tree.
  const invokeStore = useInvokeStore();
  const { preflightCommand, preflightSlug } = invokeStore;

  // Document-level keydown for global shortcuts. The listener is registered
  // once on mount so it captures keystrokes regardless of which child element
  // currently holds focus, and is cleaned up on unmount.
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      // ⌘K / Ctrl+K — open CommandPalette.
      if ((event.metaKey || event.ctrlKey) && event.key === "k") {
        event.preventDefault();
        setPaletteOpen(true);
        return;
      }
      // Esc — close both overlays.
      if (event.key === "Escape") {
        setPaletteOpen(false);
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, []);

  return (
    <ThemeProvider>
      <I18nProvider>
        <SettingsProvider>
          <SessionsProvider>
            <Routes>
              <Route path="/" element={<MainWindow />} />
              <Route path="/repo/:repoId" element={<MainWindow />} />
              <Route path="/feature/:repoId/:slug" element={<CardDetail />} />
              <Route path="/settings" element={<Settings />} />
              <Route path="/compact" element={<CompactPanel />} />
            </Routes>

            {/* CommandPalette — top-level overlay, controlled by paletteOpen state.
                Mounted unconditionally so it can receive focus on open without
                a React tree insertion delay. */}
            <CommandPalette
              open={paletteOpen}
              onClose={() => setPaletteOpen(false)}
            />

            {/* PreflightToast — driven by invokeStore's toast-visibility signal.
                Shown for 3s after a successful terminal-spawn (AC5.c). */}
            {preflightCommand !== null && preflightSlug !== null && (
              <PreflightToast
                command={preflightCommand}
                slug={preflightSlug}
                onDismiss={() => {
                  /* invokeStore clears preflightCommand after 3s internally;
                     the toast's own 3s timer calls onDismiss as belt-and-braces.
                     No explicit store setter is exposed, so onDismiss is a no-op
                     here — the store's internal timeout will clear the state. */
                }}
              />
            )}
          </SessionsProvider>
        </SettingsProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}

export default App;
