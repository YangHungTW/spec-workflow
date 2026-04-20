import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { invoke } from "@tauri-apps/api/core";
import { useTranslation } from "../i18n";
import { SettingsGeneral } from "../components/SettingsGeneral";
import { SettingsNotifications } from "../components/SettingsNotifications";
import { SettingsRepositories } from "../components/SettingsRepositories";
import type { Theme } from "../stores/themeStore";

/** Shape of the settings payload from the get_settings / update_settings IPC commands (T11). */
export interface AppSettings {
  theme: Theme;
  locale: "en" | "zh-TW";
  polling_interval_secs: number;
  stale_threshold_mins: number;
  stalled_threshold_mins: number;
  notifications_enabled: boolean;
  repositories: string[];
}

const DEFAULT_SETTINGS: AppSettings = {
  theme: "light",
  locale: "en",
  polling_interval_secs: 3,
  stale_threshold_mins: 10,
  stalled_threshold_mins: 30,
  notifications_enabled: true,
  repositories: [],
};

type TabKey = "general" | "notifications" | "repositories";

function Settings() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<TabKey>("general");
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [thresholdError, setThresholdError] = useState<string | null>(null);

  useEffect(() => {
    invoke<AppSettings>("get_settings")
      .then((loaded) => setSettings(loaded))
      .catch(() => undefined);
  }, []);

  function handleSettingsChange(patch: Partial<AppSettings>) {
    setSettings((prev) => ({ ...prev, ...patch }));
  }

  const TABS: { key: TabKey; label: string }[] = [
    { key: "general", label: t("settings.general") },
    { key: "notifications", label: t("settings.notifications") },
    { key: "repositories", label: t("settings.repositories") },
  ];

  return (
    <div className="settings-view">
      {/* Back button — navigates to the main window */}
      <button
        type="button"
        className="settings-view__back-btn"
        data-testid="back-btn"
        onClick={() => navigate("/")}
      >
        ← {t("btn.back")}
      </button>
      <div role="tablist" className="settings-tablist" aria-label="Settings">
        {TABS.map(({ key, label }) => (
          <button
            key={key}
            role="tab"
            aria-selected={activeTab === key}
            aria-controls={`settings-panel-${key}`}
            id={`settings-tab-${key}`}
            onClick={() => setActiveTab(key)}
            className={`settings-tab${activeTab === key ? " settings-tab--active" : ""}`}
          >
            {label}
          </button>
        ))}
      </div>

      <div
        role="tabpanel"
        id={`settings-panel-${activeTab}`}
        aria-labelledby={`settings-tab-${activeTab}`}
        className="settings-panel"
      >
        {activeTab === "general" && (
          <SettingsGeneral
            settings={settings}
            onSettingsChange={handleSettingsChange}
            thresholdError={thresholdError}
            onThresholdError={setThresholdError}
          />
        )}
        {activeTab === "notifications" && (
          <SettingsNotifications
            settings={settings}
            onSettingsChange={handleSettingsChange}
          />
        )}
        {activeTab === "repositories" && (
          <SettingsRepositories
            settings={settings}
            onSettingsChange={handleSettingsChange}
          />
        )}
      </div>
    </div>
  );
}

export default Settings;
