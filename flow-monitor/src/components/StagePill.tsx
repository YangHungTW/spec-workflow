import { useTranslation } from "../i18n";

/**
 * The 11 named stages in scaff order.
 * Unknown is excluded — it is an error state, not a displayable stage.
 */
export const STAGE_KEYS = [
  "request",
  "brainstorm",
  "design",
  "prd",
  "tech",
  "plan",
  "tasks",
  "implement",
  "gap-check",
  "verify",
  "archive",
] as const;

export type StageKey = (typeof STAGE_KEYS)[number];

interface StagePillProps {
  stage: StageKey;
}

/**
 * Pure presentational pill showing the current scaff stage.
 * Label from t("stage.<key>"). Colors from CSS tokens --stage-<key>-bg / --stage-<key>-fg
 * defined in theme.css (T13). No hooks, no useEffect, no IPC calls.
 */
export function StagePill({ stage }: StagePillProps) {
  const { t } = useTranslation();

  return (
    <span
      role="status"
      data-stage={stage}
      style={{
        backgroundColor: `var(--stage-${stage}-bg)`,
        color: `var(--stage-${stage}-fg)`,
      }}
      className="stage-pill"
    >
      {t(`stage.${stage}`)}
    </span>
  );
}
