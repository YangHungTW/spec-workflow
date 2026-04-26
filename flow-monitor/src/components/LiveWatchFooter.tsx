import { useWatcherStatus } from "../stores/artifactStore";
import { useTranslation } from "../i18n";

/**
 * LiveWatchFooter — sidebar footer showing FS-watcher health.
 *
 * AC15: no numeric interval displayed (R15).
 * AC16: pip pulses green when state === "running"; static grey when errored.
 * Label comes from i18n key "sidebar.liveFsWatch" (registered in T12 — falls
 * back to the key string if the bundle hasn't landed yet).
 */
export function LiveWatchFooter() {
  const { t } = useTranslation();
  const { state } = useWatcherStatus();

  const isRunning = state === "running";

  return (
    <div
      className="live-watch-footer"
      data-testid="live-watch-footer"
    >
      <span
        className={
          isRunning
            ? "live-watch-footer__pip live-watch-footer__pip--running"
            : "live-watch-footer__pip live-watch-footer__pip--errored"
        }
        aria-hidden="true"
        data-testid="live-watch-pip"
        data-state={state}
      />
      <span className="live-watch-footer__label">
        {t("sidebar.liveFsWatch")}
      </span>
    </div>
  );
}

export default LiveWatchFooter;
