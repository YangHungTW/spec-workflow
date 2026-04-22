import { invoke } from "@tauri-apps/api/core";
import { useTranslation } from "../i18n";
import { StagePill, STAGE_KEYS, type StageKey } from "./StagePill";
import { IdleBadge, type IdleState } from "./IdleBadge";
import { ActionStrip } from "./ActionStrip";
import { AgentPill } from "./AgentPill";
import { roleForSession } from "../agentPalette";
import type { SessionState } from "../stores/sessionStore";
import type { InvokeStore } from "../stores/invokeStore";

export interface SessionCardProps {
  slug: string;
  stage: StageKey;
  idleState: IdleState;
  /** Unix timestamp in ms of last update */
  lastUpdatedMs: number;
  /** First ≤80 chars of the newest Notes line */
  noteExcerpt: string;
  /** Absolute path to the feature directory (used by hover actions) */
  repoPath: string;
  /** Repository name shown above the slug (T48.7) */
  repoName?: string;
  /** Whether the session has a UI (02-design folder present); shows purple "UI" badge (T48.8) */
  hasUi?: boolean;
  /** Called when card body is clicked — opens CardDetail view */
  onClick?: () => void;
  /**
   * Full session state — required to mount ActionStrip on stalled cards (T106).
   * When absent the stalled gate is skipped (backward-compatible with B1 callers).
   */
  session?: SessionState;
  /**
   * Invoke store — required to wire ActionStrip's onAdvance handler (T106).
   * When absent the stalled gate is skipped.
   */
  invokeStore?: InvokeStore;
}

/**
 * Format a timestamp as a human-readable relative time string.
 * Produces strings like "2m ago", "1h ago", "3d ago".
 * Pure function — no side effects.
 */
function formatRelativeTime(ms: number): string {
  const diffSec = Math.max(0, Math.floor((Date.now() - ms) / 1000));
  if (diffSec < 60) return `${diffSec}s ago`;
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  return `${Math.floor(diffHr / 24)}d ago`;
}

/**
 * SessionCard — presentational card for one scaff session.
 *
 * Six elements per card (AC7.a):
 *   1. slug
 *   2. StagePill
 *   3. relative time
 *   4. IdleBadge (or "Active" badge when healthy)
 *   5. note excerpt (truncated to ≤80 chars)
 *   6. hover actions — EXACTLY "Open in Finder" + "Copy path" (AC7.d)
 *
 * T48 additions:
 *   - Repo name row above slug (T48.7)
 *   - "UI" badge (purple pill) when hasUi === true (T48.8)
 *   - "Active" badge (green pill) when idleState === "none" (T48.8)
 *   - Stalled: all text recolored to var(--stalled-red) (T48.7)
 *   - Stale: all text recolored to var(--stale-amber) (T48.7)
 *
 * B2 boundary enforced: no "Send instruction", "Advance stage", or "Edit" action.
 */
export function SessionCard({
  slug,
  stage,
  idleState,
  lastUpdatedMs,
  noteExcerpt,
  repoPath,
  repoName,
  hasUi = false,
  onClick,
  session,
  invokeStore,
}: SessionCardProps) {
  const { t } = useTranslation();

  // Truncate note excerpt to ≤80 chars at component level (AC7.a)
  const displayExcerpt =
    noteExcerpt.length > 80 ? noteExcerpt.slice(0, 80) : noteExcerpt;

  function handleOpenInFinder(e: React.MouseEvent) {
    e.stopPropagation();
    invoke("open_in_finder", { path: repoPath }).catch(() => undefined);
  }

  function handleCopyPath(e: React.MouseEvent) {
    e.stopPropagation();
    navigator.clipboard.writeText(repoPath).catch(() => undefined);
  }

  const cardClass = [
    "session-card",
    idleState === "stalled" ? "session-card--stalled" : "",
    idleState === "stale" ? "session-card--stale" : "",
  ]
    .filter(Boolean)
    .join(" ");

  // "Active" badge shown when session is healthy (no idle state)
  const showActiveBadge = idleState === "none";

  // Compute next stage for ActionStrip dispatch — mirrors ActionStrip.tsx logic.
  // Resolves to the stage key that follows the current one in the STAGE_KEYS list.
  const currentStageIndex = STAGE_KEYS.indexOf(stage as StageKey);
  const nextStageKey: string | undefined =
    currentStageIndex >= 0 && currentStageIndex < STAGE_KEYS.length - 1
      ? STAGE_KEYS[currentStageIndex + 1]
      : undefined;

  return (
    <article
      className={cardClass}
      data-slug={slug}
      onClick={onClick}
      role={onClick ? "button" : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={onClick ? (e) => { if (e.key === "Enter") onClick(); } : undefined}
    >
      <header className="session-card__header">
        {/* Repo name row + UI badge — T48.7 */}
        <div className="session-card__repo-row">
          {repoName && (
            <span className="session-card__repo-name">{repoName}</span>
          )}
          {hasUi && (
            <span className="session-card__ui-badge" data-testid="ui-badge">
              UI
            </span>
          )}
        </div>

        {/* Slug + Stage pill row */}
        <div className="session-card__slug-row">
          <span className="session-card__slug">{slug}</span>
          <StagePill stage={stage} />
        </div>

        {/* Agent role row — between slug/stage and note excerpt (D5, AC9) */}
        <div className="session-card__agent-row">
          <AgentPill role={roleForSession({ stage })} />
        </div>
      </header>

      {displayExcerpt && (
        <p
          className="session-card__note"
          data-testid="note-excerpt"
        >
          {displayExcerpt}
        </p>
      )}

      <div className="session-card__meta">
        <span
          className="session-card__time"
          data-testid="relative-time"
          title={new Date(lastUpdatedMs).toISOString()}
        >
          <svg width="10" height="10" fill="none" viewBox="0 0 10 10" aria-hidden="true">
            <circle cx="5" cy="5" r="4" stroke="currentColor" strokeWidth="1.2" />
            <path d="M5 3v2l1.5 1" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
          </svg>
          {formatRelativeTime(lastUpdatedMs)}
        </span>

        {/* Right side: Active badge (green) OR IdleBadge (stale/stalled) */}
        {showActiveBadge ? (
          <span className="session-card__active-badge" data-testid="active-badge">
            {t("card.active")}
          </span>
        ) : (
          <IdleBadge state={idleState} />
        )}
      </div>

      {/* Hover actions — EXACTLY 2 per AC7.d; B2 boundary: no edit/advance/send */}
      <div className="session-card__actions">
        <button
          type="button"
          className="session-card__action"
          onClick={handleOpenInFinder}
        >
          {t("btn.openInFinder")}
        </button>
        <button
          type="button"
          className="session-card__action"
          onClick={handleCopyPath}
        >
          {t("btn.copyPath")}
        </button>
      </div>

      {/* AC2.b — ActionStrip only on stalled cards; session + invokeStore must be present.
          stopPropagation prevents ActionStrip button clicks from bubbling to the card's
          onClick handler, which would navigate to Card Detail unintentionally on Advance. */}
      {idleState === "stalled" && session && invokeStore && nextStageKey && (
        <div
          onClick={(e) => e.stopPropagation()}
          onKeyDown={(e) => e.stopPropagation()}
        >
          <ActionStrip
            session={session}
            onAdvance={() => {
              void invokeStore.dispatch(
                nextStageKey,
                slug,
                repoPath,
                "card-action",
                "terminal",
              );
            }}
            onMessage={() => {
              onClick?.();
            }}
          />
        </div>
      )}
    </article>
  );
}

export default SessionCard;
