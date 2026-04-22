import { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { useTranslation } from "../i18n";
import { StagePill, STAGE_KEYS, type StageKey } from "./StagePill";
import { IdleBadge, type IdleState } from "./IdleBadge";
import { SendPanel } from "./SendPanel";
import { AgentPill } from "./AgentPill";
import { roleForSession } from "../agentPalette";
import type { InvokeStore } from "../stores/invokeStore";

/**
 * Returns the stage key that follows `stage` in the ordered STAGE_KEYS list,
 * or null if `stage` is the last stage (archive — no valid next stage).
 * Used by both the Advance button guard and the dispatch call (AC3.a).
 */
function nextStage(stage: StageKey): StageKey | null {
  const idx = STAGE_KEYS.indexOf(stage);
  if (idx < 0 || idx >= STAGE_KEYS.length - 1) return null;
  return STAGE_KEYS[idx + 1];
}

export interface CardDetailHeaderProps {
  repoId: string;
  slug: string;
  stage: StageKey;
  idleState: IdleState;
  /** Absolute path to the feature directory (used by action buttons) */
  featurePath: string;
  /** Called when the breadcrumb back arrow is clicked */
  onBack: () => void;
  /** invokeStore — required for Advance dispatch (T107). */
  invokeStore: InvokeStore;
}

/**
 * CardDetailHeader — breadcrumb strip + feature title + stage pill + idle badge
 * + action buttons.
 *
 * T107 additions (Screen 2):
 *   Advance button — calls invokeStore.dispatch with next stage; hidden when
 *   nextStage(stage) === null (AC3.a — session at archive has no next stage).
 *   Message / Choice button — toggles inline SendPanel mount (local state
 *   showSendPanel); hidden together with Advance per AC3.a.
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
  invokeStore,
}: CardDetailHeaderProps) {
  const { t } = useTranslation();
  const [showSendPanel, setShowSendPanel] = useState(false);

  const next = nextStage(stage);

  function handleOpenInFinder() {
    invoke("open_in_finder", { path: featurePath }).catch(() => undefined);
  }

  function handleCopyPath() {
    navigator.clipboard.writeText(featurePath).catch(() => undefined);
  }

  function handleAdvance() {
    if (next === null) return;
    void invokeStore.dispatch(next, slug, repoId, "card-detail", "terminal");
  }

  function handleMessage() {
    setShowSendPanel((prev) => !prev);
  }

  return (
    <>
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

        {/* Stage pill, agent pill, and idle badge */}
        <div className="card-detail-header__badges">
          <StagePill stage={stage} />
          <AgentPill role={roleForSession({ stage })} />
          {idleState !== "none" && <IdleBadge state={idleState} />}
        </div>

        {/* Utility action row — Open in Finder + Copy path */}
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

        {/* Control-plane buttons — hidden when session is at archive (AC3.a) */}
        {next !== null && (
          <div className="card-detail-header__control">
            <button
              type="button"
              className="card-detail-header__advance"
              onClick={handleAdvance}
            >
              {t(`action.advance_to.${next}`)}
            </button>
            <button
              type="button"
              className="card-detail-header__message"
              onClick={handleMessage}
            >
              {t("action.message")}
            </button>
          </div>
        )}
      </header>

      {/* SendPanel — mounted below header when toggled by Message / Choice */}
      {showSendPanel && next !== null && (
        <SendPanel
          command={next}
          slug={slug}
          repo={repoId}
          entry="card-detail"
          invokeStore={invokeStore}
        />
      )}
    </>
  );
}

export default CardDetailHeader;
