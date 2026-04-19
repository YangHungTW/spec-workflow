import { useTranslation } from "../i18n";

/**
 * The 3 idle states for a session.
 * "none" means the session is active (no badge needed).
 */
export const IDLE_STATES = ["none", "stale", "stalled"] as const;

export type IdleState = (typeof IDLE_STATES)[number];

interface IdleBadgeProps {
  state: IdleState;
}

/**
 * Pure presentational badge showing the idle state of a session.
 * Label from t("idle.<state>"). Colors from CSS tokens --idle-<state>-bg / --idle-<state>-fg
 * defined in theme.css (T13). No hooks, no useEffect, no IPC calls.
 * Static — no repeating visual change driven by CSS (AC9.j).
 */
export function IdleBadge({ state }: IdleBadgeProps) {
  const { t } = useTranslation();

  return (
    <span
      data-idle-state={state}
      style={{
        backgroundColor: `var(--idle-${state}-bg)`,
        color: `var(--idle-${state}-fg)`,
      }}
      className="idle-badge"
    >
      {t(`idle.${state}`)}
    </span>
  );
}
