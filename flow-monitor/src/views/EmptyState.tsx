import { useTranslation } from "../i18n";
import { invoke } from "@tauri-apps/api/core";
import { useNavigate } from "react-router-dom";

/**
 * EmptyState view — shown when zero repositories are registered.
 *
 * AC12.a: displays title, body explainer, and CTA when no repos exist.
 * AC12.b: CTA opens folder picker; on success invokes add_repo IPC then
 *         navigates to / (All Projects view).
 * AC12.c: sidebar ghost item is rendered at the layout level (Sidebar.tsx);
 *         this view provides the main panel content only.
 * R-5 mitigation: explainer text mentions notifications as a soft prompt
 *   before the OS-level permission dialog fires on first stalled transition.
 */
function EmptyState() {
  const { t } = useTranslation();
  const navigate = useNavigate();

  async function handleAddRepo() {
    // Invoke the Tauri dialog command directly via IPC; avoids a hard
    // dependency on @tauri-apps/plugin-dialog in this module while keeping
    // tests mockable via @tauri-apps/api/core mock.
    const selected = await invoke<string | null>("dialog_open_directory");
    if (!selected) {
      return;
    }
    await invoke("add_repo", { path: selected });
    navigate("/");
  }

  return (
    <div className="empty-state">
      <h1 className="empty-state__title">{t("empty.title")}</h1>
      <p className="empty-state__body">{t("empty.body")}</p>
      {/* Soft-prompt before OS notification permission dialog fires (R-5 mitigation) */}
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
    </div>
  );
}

export default EmptyState;
