import { useEffect, useState } from "react";
import { useTranslation } from "../i18n";
import { invoke } from "@tauri-apps/api/core";
import type { AppSettings } from "../views/Settings";

type PermissionStatus = "granted" | "denied" | "default";

interface SettingsNotificationsProps {
  settings: AppSettings;
  onSettingsChange: (patch: Partial<AppSettings>) => void;
}

export function SettingsNotifications({
  settings,
  onSettingsChange,
}: SettingsNotificationsProps) {
  const { t } = useTranslation();
  const [permissionStatus, setPermissionStatus] = useState<PermissionStatus | null>(null);

  // Fetch macOS notification permission status on mount (AC6.e / R-5 mitigation).
  // Falls back to browser Notification.permission when the Tauri IPC is unavailable.
  useEffect(() => {
    invoke<PermissionStatus>("get_notification_permission_status")
      .then((status) => setPermissionStatus(status))
      .catch(() => {
        // Tauri IPC unavailable (e.g. running in browser dev-mode); fall back
        // to the browser Notification API permission value.
        if (typeof Notification !== "undefined") {
          const p = Notification.permission as PermissionStatus;
          setPermissionStatus(p);
        }
      });
  }, []);

  function handleToggle(e: React.ChangeEvent<HTMLInputElement>) {
    const enabled = e.target.checked;
    const patch = { notifications_enabled: enabled };
    onSettingsChange(patch);
    invoke("update_settings", patch).catch(() => undefined);
  }

  function statusLabel(status: PermissionStatus): string {
    if (status === "granted") return t("settings.notifications.statusGranted");
    if (status === "denied") return t("settings.notifications.statusDenied");
    return t("settings.notifications.statusDefault");
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
          {t("settings.enableNotifications")}
        </label>

        {permissionStatus !== null && (
          <p
            className="settings-notifications__permission-status"
            data-testid="notification-permission-status"
          >
            {t("settings.notifications.permissionStatus")}{" "}
            {statusLabel(permissionStatus)}
          </p>
        )}

        {permissionStatus === "denied" && (
          <p
            className="settings-notifications__denied-hint"
            data-testid="notification-denied-hint"
          >
            {t("settings.notifications.deniedHint")}
          </p>
        )}
      </section>
    </div>
  );
}
