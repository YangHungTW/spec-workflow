import { useTranslation } from "../i18n";
import { STAGE_KEYS, type StageKey } from "./StagePill";
import type { SessionState } from "../stores/sessionStore";

export interface ActionStripProps {
  session: SessionState;
  onAdvance: () => void;
  onMessage: () => void;
}

/**
 * ActionStrip — two-button row for stalled session cards (T100).
 *
 * Primary button: "Advance to <next_stage>" — label from i18n key
 * `action.advance_to.<next_stage>`. The next stage is derived from the
 * ordered STAGE_KEYS list; if the session is at the last stage the
 * primary button label falls back to the bare key (no caller should
 * show ActionStrip for an archived session per T106 gating logic).
 *
 * Secondary button: "Message / Choice" — label from i18n key
 * `action.message`. Opens Card Detail (caller wires onMessage).
 *
 * Pure display — no render gating. Parent (T106) decides when to mount.
 * Uses --button-primary-* / --button-secondary-* tokens from T97 map.
 */
export function ActionStrip({ session, onAdvance, onMessage }: ActionStripProps) {
  const { t } = useTranslation();

  const currentIndex = STAGE_KEYS.indexOf(session.stage as StageKey);
  const nextStage: string | undefined =
    currentIndex >= 0 && currentIndex < STAGE_KEYS.length - 1
      ? STAGE_KEYS[currentIndex + 1]
      : undefined;

  const primaryLabel = nextStage
    ? t(`action.advance_to.${nextStage}`)
    : t("action.advance_to.done");

  const secondaryLabel = t("action.message");

  return (
    <div className="action-strip">
      <button
        type="button"
        className="action-strip__primary"
        style={{
          backgroundColor: "var(--button-primary-bg)",
          color: "var(--button-primary-fg)",
        }}
        onClick={onAdvance}
      >
        {primaryLabel}
      </button>
      <button
        type="button"
        className="action-strip__secondary"
        style={{
          backgroundColor: "var(--button-secondary-bg)",
          color: "var(--button-secondary-fg)",
        }}
        onClick={onMessage}
      >
        {secondaryLabel}
      </button>
    </div>
  );
}

export default ActionStrip;
