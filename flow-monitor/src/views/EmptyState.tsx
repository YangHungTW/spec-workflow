import { useEffect, useState } from "react";
import { useTranslation } from "../i18n";
import { invoke } from "@tauri-apps/api/core";
import { useNavigate } from "react-router-dom";

function EmptyState() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [status, setStatus] = useState<string>("idle");
  const [selectedPath, setSelectedPath] = useState<string | null>(null);
  const [sessionCount, setSessionCount] = useState<number>(0);
  const [repoCount, setRepoCount] = useState<number>(0);
  const [lastError, setLastError] = useState<string | null>(null);

  // Poll diagnostic info every 2 seconds
  useEffect(() => {
    const tick = async () => {
      try {
        const sessions = await invoke<unknown[]>("list_sessions");
        setSessionCount(sessions.length);
        const settings = await invoke<{ repos: string[] }>("get_settings");
        setRepoCount(settings.repos?.length ?? 0);
      } catch (e) {
        setLastError(`poll: ${e}`);
      }
    };
    void tick();
    const id = window.setInterval(() => void tick(), 2000);
    return () => window.clearInterval(id);
  }, []);

  async function handleAddRepo() {
    setLastError(null);
    setStatus("opening picker");
    try {
      const selected = await invoke<string | null>("dialog_open_directory");
      setSelectedPath(selected);
      if (!selected) {
        setStatus("cancelled");
        return;
      }
      setStatus(`calling add_repo with ${selected}`);
      await invoke("add_repo", { path: selected });
      setStatus("add_repo success, waiting for polling tick");
      // Do NOT navigate — stay here to observe
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setLastError(`Failed: ${msg}`);
      setStatus("failed");
    }
  }

  const diag = {
    status,
    selectedPath,
    repoCount,
    sessionCount,
    lastError,
  };

  return (
    <div className="empty-state">
      <h1 className="empty-state__title">{t("empty.title")}</h1>
      <p className="empty-state__body">{t("empty.body")}</p>
      <button
        className="empty-state__cta"
        type="button"
        onClick={() => { void handleAddRepo(); }}
      >
        {t("empty.cta")}
      </button>

      <pre
        style={{
          marginTop: 24,
          padding: 12,
          background: "var(--surface-secondary)",
          border: "1px solid var(--card-border)",
          borderRadius: 8,
          fontSize: 11,
          color: "var(--text-muted)",
          maxWidth: 500,
          textAlign: "left",
          whiteSpace: "pre-wrap",
          wordBreak: "break-all",
        }}
      >
        {JSON.stringify(diag, null, 2)}
      </pre>

      {sessionCount > 0 && (
        <button
          type="button"
          onClick={() => navigate("/")}
          style={{
            marginTop: 8,
            padding: "8px 16px",
            background: "var(--primary)",
            color: "var(--card-bg)",
            border: "none",
            borderRadius: 6,
            cursor: "pointer",
          }}
        >
          {sessionCount} session(s) found — go to main
        </button>
      )}
    </div>
  );
}

export default EmptyState;
