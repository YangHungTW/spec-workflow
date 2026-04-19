import { invoke } from "@tauri-apps/api/core";
import { useTranslation } from "../i18n";
import { StagePill, type StageKey } from "./StagePill";
import { IdleBadge, type IdleState } from "./IdleBadge";

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
 * SessionCard — presentational card for one specflow session.
 *
 * Six elements per card (AC7.a):
 *   1. slug
 *   2. StagePill
 *   3. relative time
 *   4. IdleBadge
 *   5. note excerpt (truncated to ≤80 chars)
 *   6. hover actions — EXACTLY "Open in Finder" + "Copy path" (AC7.d)
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
}: SessionCardProps) {
  const { t } = useTranslation();

  // Truncate note excerpt to ≤80 chars at component level (AC7.a)
  const displayExcerpt =
    noteExcerpt.length > 80 ? noteExcerpt.slice(0, 80) : noteExcerpt;

  function handleOpenInFinder() {
    invoke("open_in_finder", { path: repoPath }).catch(() => undefined);
  }

  function handleCopyPath() {
    navigator.clipboard.writeText(repoPath).catch(() => undefined);
  }

  return (
    <article className="session-card" data-slug={slug}>
      <header className="session-card__header">
        <span className="session-card__slug">{slug}</span>
        <StagePill stage={stage} />
        <IdleBadge state={idleState} />
      </header>

      <div className="session-card__meta">
        <span
          className="session-card__time"
          data-testid="relative-time"
          title={new Date(lastUpdatedMs).toISOString()}
        >
          {formatRelativeTime(lastUpdatedMs)}
        </span>
      </div>

      {displayExcerpt && (
        <p
          className="session-card__note"
          data-testid="note-excerpt"
        >
          {displayExcerpt}
        </p>
      )}

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
    </article>
  );
}

export default SessionCard;
