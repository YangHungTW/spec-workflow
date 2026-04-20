import { useState } from "react";
import { useTranslation } from "../i18n";
import { invoke } from "@tauri-apps/api/core";
import { useNavigate } from "react-router-dom";

function EmptyState() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);

  async function handleAddRepo() {
    setError(null);
    try {
      const selected = await invoke<string | null>("dialog_open_directory");
      if (!selected) {
        setError("Dialog returned no selection (cancelled or no permission)");
        return;
      }
      await invoke("add_repo", { path: selected });
      navigate("/");
    } catch (e) {
      setError(`Failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  return (
    <div className="empty-state">
      <h1 className="empty-state__title">{t("empty.title")}</h1>
      <p className="empty-state__body">{t("empty.body")}</p>
      <p className="empty-state__notification-prompt" data-testid="notification-prompt">
        {t("empty.notificationPrompt")}
      </p>
      <button
        className="empty-state__cta"
        type="button"
        onClick={() => { void handleAddRepo(); }}
      >
        {t("empty.cta")}
      </button>
      {error && (
        <p style={{ color: "var(--stalled-red)", fontSize: 12, marginTop: 16, maxWidth: 380 }}>
          {error}
        </p>
      )}
    </div>
  );
}

export default EmptyState;
