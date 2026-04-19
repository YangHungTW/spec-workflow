import { useTranslation } from "../i18n";
import { StagePill, type StageKey } from "../components/StagePill";
import { invoke } from "@tauri-apps/api/core";

/**
 * One row of data passed to CompactPanel from the session store.
 * Relative time is pre-formatted by the caller so this component stays pure.
 */
export interface CompactSession {
  key: string;
  slug: string;
  stage: StageKey;
  relativeTime: string;
  idleState: "none" | "stale" | "stalled";
}

interface CompactPanelProps {
  /** Active sessions to display. Defaults to [] before T35 wiring injects the store. */
  sessions?: CompactSession[];
}

/**
 * CompactPanel view — rendered in a separate Tauri WebviewWindow.
 *
 * AC10.a: one row per active session: coloured-dot · slug · stage-pill · relative-time.
 * AC10.b: no "Send instruction" / "Quick advance" buttons (B2 boundary).
 * AC10.d: free-floating + draggable via Tauri WebviewWindow config (T3/T35).
 * AC10.e: "Open main" affordance at the bottom invokes focus_main_window IPC.
 * Always-on-top toggle is wired in W4 T34 — not present here.
 */
function CompactPanel({ sessions = [] }: CompactPanelProps) {
  const { t } = useTranslation();

  function handleOpenMain() {
    void invoke("focus_main_window");
  }

  return (
    <div className="compact-panel">
      <ul className="compact-panel__list">
        {sessions.map((session) => (
          <li key={session.key} className="compact-panel__row">
            <span
              className="compact-panel__dot"
              data-testid="session-dot"
              data-idle-state={session.idleState}
              aria-hidden="true"
            />
            <span className="compact-panel__slug">{session.slug}</span>
            <StagePill stage={session.stage} />
            <span className="compact-panel__time">{session.relativeTime}</span>
          </li>
        ))}
      </ul>
      <button
        className="compact-panel__open-main"
        type="button"
        onClick={handleOpenMain}
      >
        {t("btn.openMain")}
      </button>
    </div>
  );
}

export default CompactPanel;
