import { useTranslation } from "../i18n";
import { STAGE_KEYS, type StageKey } from "./StagePill";

interface StageChecklistProps {
  currentStage: StageKey;
}

/**
 * StageChecklist — display-only 11-stage progress list.
 *
 * AC9.e (B1 carve-out): stage items are NEVER toggleable — no click handlers,
 * no role="button", no interactive affordance. Purely presentational.
 *
 * Current stage highlighted using --primary token per [CHANGED 2026-04-19] AC9
 * carve-out + R15. Stages before current are marked completed; stages after
 * current are marked pending.
 */
export function StageChecklist({ currentStage }: StageChecklistProps) {
  const { t } = useTranslation();

  const currentIndex = STAGE_KEYS.indexOf(currentStage);

  return (
    <ol
      className="stage-checklist"
      data-testid="stage-checklist"
      aria-label="Stage progress"
    >
      {STAGE_KEYS.map((stage, index) => {
        const isCompleted = index < currentIndex;
        const isCurrent = index === currentIndex;

        return (
          <li
            key={stage}
            className="stage-checklist__item"
            data-stage-item={stage}
            data-completed={isCompleted ? "true" : undefined}
            data-current={isCurrent ? "true" : undefined}
            style={
              isCurrent
                ? { color: "var(--primary)", fontWeight: "bold" }
                : undefined
            }
          >
            <span className="stage-checklist__marker" aria-hidden="true">
              {isCompleted ? "✓" : isCurrent ? "▶" : "○"}
            </span>
            <span className="stage-checklist__label">{t(`stage.${stage}`)}</span>
          </li>
        );
      })}
    </ol>
  );
}

export default StageChecklist;
