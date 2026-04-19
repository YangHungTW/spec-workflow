import { invoke } from "@tauri-apps/api/core";
import { useTranslation } from "../i18n";
import { StagePill, type StageKey } from "./StagePill";
import { IdleBadge, type IdleState } from "./IdleBadge";

export interface CardDetailHeaderProps {
  repoId: string;
  slug: string;
  stage: StageKey;
  idleState: IdleState;
  /** Absolute path to the feature directory (used by action buttons) */
  featurePath: string;
  /** Called when the breadcrumb back arrow is clicked */
  onBack: () => void;
}

/**
 * CardDetailHeader — breadcrumb strip + feature title + stage pill + idle badge
 * + exactly 2 action buttons (Open in Finder, Copy path).
 *
 * B2 boundary enforced: NO "Send instruction", NO "Advance stage", NO "Edit"
 * button. Exactly 2 actions per AC7.d-parallel (same pattern as SessionCard).
 *
 * The "Open in Finder" button opens the FEATURE DIRECTORY (not any sub-file).
 * Sub-file Reveal comes in T20 (DesignFolderIndex).
 *
 * AC9.j: IdleBadge is static — no animation or transition inline style.
 */
export function CardDetailHeader({
  repoId,
  slug,
  stage,
  idleState,
  featurePath,
  onBack,
}: CardDetailHeaderProps) {
  const { t } = useTranslation();

  function handleOpenInFinder() {
    invoke("open_in_finder", { path: featurePath }).catch(() => undefined);
  }

  function handleCopyPath() {
    navigator.clipboard.writeText(featurePath).catch(() => undefined);
  }

  return (
    <header className="card-detail-header" data-testid="card-detail-header">
      {/* Breadcrumb back arrow */}
      <button
        type="button"
        className="card-detail-header__back"
        aria-label={t("btn.back")}
        onClick={onBack}
      >
        ←
      </button>

      {/* Title: repo/slug */}
      <h1 className="card-detail-header__title">
        {repoId}/{slug}
      </h1>

      {/* Stage pill and idle badge */}
      <div className="card-detail-header__badges">
        <StagePill stage={stage} />
        {idleState !== "none" && <IdleBadge state={idleState} />}
      </div>

      {/* Action row — EXACTLY 2 buttons per AC7.d-parallel; B2 boundary enforced */}
      <div className="card-detail-header__actions">
        <button
          type="button"
          className="card-detail-header__action"
          onClick={handleOpenInFinder}
        >
          {t("btn.openInFinder")}
        </button>
        <button
          type="button"
          className="card-detail-header__action"
          onClick={handleCopyPath}
        >
          {t("btn.copyPath")}
        </button>
      </div>
    </header>
  );
}

export default CardDetailHeader;
