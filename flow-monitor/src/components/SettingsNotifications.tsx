import { useTranslation } from "../i18n";
import { invoke } from "@tauri-apps/api/core";
import type { AppSettings } from "../views/Settings";

interface SettingsNotificationsProps {
  settings: AppSettings;
  onSettingsChange: (patch: Partial<AppSettings>) => void;
}

export function SettingsNotifications({
  settings,
  onSettingsChange,
}: SettingsNotificationsProps) {
  const { t } = useTranslation();

  function handleToggle(e: React.ChangeEvent<HTMLInputElement>) {
    const enabled = e.target.checked;
    const patch = { notifications_enabled: enabled };
    onSettingsChange(patch);
    invoke("update_settings", patch).catch(() => undefined);
  }

  return (
    <div className="settings-notifications">
      <section className="settings-section">
        <h3 className="settings-section-title">{t("settings.notifications")}</h3>
        <label className="settings-toggle-label">
          <input
            type="checkbox"
            role="checkbox"
            aria-label={t("settings.notifications")}
            checked={settings.notifications_enabled}
            onChange={handleToggle}
          />
          Enable stalled-session notifications (AC6.e)
        </label>
      </section>
    </div>
  );
}
