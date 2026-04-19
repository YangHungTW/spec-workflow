import { useTranslation } from "../i18n";
import { applyThemeToDocument, type Theme } from "../stores/themeStore";
import { invoke } from "@tauri-apps/api/core";
import type { AppSettings } from "../views/Settings";

interface SettingsGeneralProps {
  settings: AppSettings;
  onSettingsChange: (patch: Partial<AppSettings>) => void;
  thresholdError: string | null;
  onThresholdError: (err: string | null) => void;
}

export function SettingsGeneral({
  settings,
  onSettingsChange,
  thresholdError,
  onThresholdError,
}: SettingsGeneralProps) {
  const { t, setLocale } = useTranslation();

  function handlePollingChange(e: React.ChangeEvent<HTMLInputElement>) {
    const raw = Number(e.target.value);
    const clamped = Math.max(2, Math.min(5, raw));
    const patch = { polling_interval_secs: clamped };
    onSettingsChange(patch);
    invoke("update_settings", patch).catch(() => undefined);
  }

  function handleStaleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const stale = Number(e.target.value);
    if (stale >= settings.stalled_threshold_mins) {
      onThresholdError(
        `Stalled threshold must be greater than stale threshold (${stale} min).`,
      );
      return;
    }
    onThresholdError(null);
    const patch = { stale_threshold_mins: stale };
    onSettingsChange(patch);
    invoke("update_settings", patch).catch(() => undefined);
  }

  function handleStalledChange(e: React.ChangeEvent<HTMLInputElement>) {
    const stalled = Number(e.target.value);
    if (stalled < settings.stale_threshold_mins) {
      onThresholdError(
        `Stalled threshold must be >= stale threshold (${settings.stale_threshold_mins} min).`,
      );
      return;
    }
    onThresholdError(null);
    const patch = { stalled_threshold_mins: stalled };
    onSettingsChange(patch);
    invoke("update_settings", patch).catch(() => undefined);
  }

  function handleThemeChange(theme: Theme) {
    applyThemeToDocument(theme);
    const patch = { theme };
    onSettingsChange(patch);
    invoke("update_settings", patch).catch(() => undefined);
  }

  function handleLocaleChange(locale: "en" | "zh-TW") {
    setLocale(locale);
    const patch = { locale };
    onSettingsChange(patch);
    invoke("update_settings", patch).catch(() => undefined);
  }

  return (
    <div className="settings-general">
      <section className="settings-section">
        <h3 className="settings-section-title">{t("settings.polling")}</h3>
        <label htmlFor="polling-slider" className="settings-label">
          {t("settings.polling")} ({settings.polling_interval_secs}s)
        </label>
        <input
          id="polling-slider"
          type="range"
          role="slider"
          aria-label={t("settings.polling")}
          min={2}
          max={5}
          step={1}
          value={settings.polling_interval_secs}
          onChange={handlePollingChange}
        />
      </section>

      <section className="settings-section">
        <h3 className="settings-section-title">{t("settings.thresholds")}</h3>
        {thresholdError && (
          <p role="alert" className="settings-error">
            {thresholdError}
          </p>
        )}
        <label htmlFor="stale-input" className="settings-label">
          Stale threshold (minutes)
        </label>
        <input
          id="stale-input"
          type="number"
          role="spinbutton"
          aria-label="Stale threshold (minutes)"
          value={settings.stale_threshold_mins}
          min={1}
          onChange={handleStaleChange}
        />
        <label htmlFor="stalled-input" className="settings-label">
          Stalled threshold (minutes)
        </label>
        <input
          id="stalled-input"
          type="number"
          role="spinbutton"
          aria-label="Stalled threshold (minutes)"
          value={settings.stalled_threshold_mins}
          min={1}
          onChange={handleStalledChange}
        />
      </section>

      <section className="settings-section">
        <h3 className="settings-section-title">{t("settings.language")}</h3>
        <label className="settings-radio-label">
          <input
            type="radio"
            name="language"
            value="en"
            checked={settings.locale === "en"}
            onChange={() => handleLocaleChange("en")}
            aria-label="English"
          />
          English
        </label>
        <label className="settings-radio-label">
          <input
            type="radio"
            name="language"
            value="zh-TW"
            checked={settings.locale === "zh-TW"}
            onChange={() => handleLocaleChange("zh-TW")}
            aria-label="繁體中文"
          />
          繁體中文
        </label>
      </section>

      <section className="settings-section">
        <h3 className="settings-section-title">Theme</h3>
        <label className="settings-radio-label">
          <input
            type="radio"
            name="theme"
            value="light"
            checked={settings.theme === "light"}
            onChange={() => handleThemeChange("light")}
            aria-label={t("settings.theme-light")}
          />
          {t("settings.theme-light")}
        </label>
        <label className="settings-radio-label">
          <input
            type="radio"
            name="theme"
            value="dark"
            checked={settings.theme === "dark"}
            onChange={() => handleThemeChange("dark")}
            aria-label={t("settings.theme-dark")}
          />
          {t("settings.theme-dark")}
        </label>
      </section>
    </div>
  );
}
