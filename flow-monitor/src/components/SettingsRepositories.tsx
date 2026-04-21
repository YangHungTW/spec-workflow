import { useState } from "react";
import { useTranslation } from "../i18n";
import { invoke } from "@tauri-apps/api/core";
import type { AppSettings } from "../views/Settings";

interface SettingsRepositoriesProps {
  settings: AppSettings;
  onSettingsChange: (patch: Partial<AppSettings>) => void;
}

export function SettingsRepositories({
  settings,
  onSettingsChange,
}: SettingsRepositoriesProps) {
  const { t } = useTranslation();
  const [repoError, setRepoError] = useState<string | null>(null);

  async function handleAddRepo() {
    setRepoError(null);
    let pickedPath: string | null = null;

    try {
      pickedPath = await invoke<string>("pick_folder");
    } catch {
      return;
    }

    if (!pickedPath) return;

    let hasSpecWorkflow = false;
    try {
      hasSpecWorkflow = await invoke<boolean>("path_exists", {
        path: `${pickedPath}/.specaffold`,
      });
    } catch {
      hasSpecWorkflow = false;
    }

    if (!hasSpecWorkflow) {
      setRepoError(t("settings.repoNotSpecflow"));
      return;
    }

    try {
      await invoke("add_repo", { path: pickedPath });
      onSettingsChange({
        repositories: [...settings.repositories, pickedPath],
      });
    } catch {
      setRepoError(t("settings.repoAddFailed"));
    }
  }

  async function handleRemoveRepo(path: string) {
    try {
      await invoke("remove_repo", { path });
      onSettingsChange({
        repositories: settings.repositories.filter((r) => r !== path),
      });
    } catch {
      // Best-effort removal — IPC error is non-fatal in UI
    }
  }

  return (
    <div className="settings-repositories">
      <section className="settings-section">
        <h3 className="settings-section-title">{t("settings.repositories")}</h3>

        {repoError && (
          <p role="alert" className="settings-error">
            {repoError}
          </p>
        )}

        <button
          type="button"
          className="btn-add-repo"
          onClick={handleAddRepo}
          aria-label={t("btn.addRepo")}
        >
          {t("btn.addRepo")}
        </button>

        {settings.repositories.length > 0 && (
          <ul className="repo-list">
            {settings.repositories.map((repoPath) => (
              <li key={repoPath} className="repo-item">
                <span className="repo-path">{repoPath}</span>
                <button
                  type="button"
                  className="btn-remove-repo"
                  onClick={() => handleRemoveRepo(repoPath)}
                  aria-label={t("btn.remove")}
                >
                  {t("btn.remove")}
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
