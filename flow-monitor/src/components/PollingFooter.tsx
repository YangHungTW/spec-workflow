import { useState, useEffect } from "react";
import { listen } from "@tauri-apps/api/event";
import { useTranslation } from "../i18n";

export interface PollingFooterProps {
  /** Polling interval in seconds (initial value from settings) */
  intervalSeconds: number;
}

/** Payload emitted by the backend on each polling cycle completion (T9). */
interface PollingCyclePayload {
  interval_secs: number;
}

/**
 * PollingFooter — sidebar footer showing polling status.
 *
 * AC4.c — shows "Polling · {interval}s" with a green dot indicator.
 * Subscribes to the `polling_cycle_complete` Tauri event (T9) to keep
 * the displayed interval in sync within 1s of slider changes in Settings.
 *
 * Initial value comes from the `intervalSeconds` prop (fetched from settings
 * IPC on mount). Subsequent updates arrive via the Tauri event system so no
 * extra IPC round-trip is needed on each cycle.
 */
export function PollingFooter({ intervalSeconds }: PollingFooterProps) {
  const { t } = useTranslation();

  // Local interval state — seeded from prop, updated by Tauri events.
  // Using local state here means the footer reacts to live polling events
  // without requiring a store update path for every cycle.
  const [liveInterval, setLiveInterval] = useState<number>(intervalSeconds);

  // Keep liveInterval in sync when the prop changes (e.g. settings saved
  // while component is mounted — Settings view writes via IPC and the parent
  // re-fetches, causing a new prop value).
  useEffect(() => {
    setLiveInterval(intervalSeconds);
  }, [intervalSeconds]);

  // Subscribe to polling_cycle_complete events from the backend (T9 poller).
  // The event payload carries the current interval_secs so the footer always
  // reflects the active poll cadence rather than the last-saved settings value.
  useEffect(() => {
    let unlisten: (() => void) | null = null;

    listen<PollingCyclePayload>("polling_cycle_complete", (event) => {
      if (typeof event.payload?.interval_secs === "number") {
        setLiveInterval(event.payload.interval_secs);
      }
    }).then((fn) => {
      unlisten = fn;
    });

    // Cleanup: unsubscribe when the component unmounts to avoid stale callbacks.
    return () => {
      if (unlisten) {
        unlisten();
      }
    };
  }, []);

  // Replace {interval} placeholder in the i18n string
  const label = t("sidebar.pollingFooter").replace(
    "{interval}",
    String(liveInterval),
  );

  return (
    <div
      className="polling-footer"
      data-testid="polling-footer"
      data-interval={String(liveInterval)}
    >
      {/* Green dot indicator (AC4.c) */}
      <span
        className="polling-footer__dot"
        aria-hidden="true"
        data-testid="polling-dot"
        style={{ color: "var(--polling-dot-color, #22c55e)" }}
      >
        ●
      </span>
      <span className="polling-footer__label">{label}</span>
    </div>
  );
}

export default PollingFooter;
