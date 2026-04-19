import { Route, Routes } from "react-router-dom";
import MainWindow from "./views/MainWindow";
import CardDetail from "./views/CardDetail";
import Settings from "./views/Settings";
import CompactPanel from "./views/CompactPanel";

function ThemeProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function I18nProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function SettingsProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function SessionsProvider({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

function App() {
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
          </SessionsProvider>
        </SettingsProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}

export default App;
