import { useTranslation } from "../i18n";

export interface PollingFooterProps {
  /** Polling interval in seconds */
  intervalSeconds: number;
}

/**
 * PollingFooter — sidebar footer showing polling status.
 *
 * AC4.c — shows "Polling · {interval}s" with a green dot indicator.
 * Pure presentational — interval value comes from settings store via props.
 */
export function PollingFooter({ intervalSeconds }: PollingFooterProps) {
  const { t } = useTranslation();

  // Replace {interval} placeholder in the i18n string
  const label = t("sidebar.pollingFooter").replace(
    "{interval}",
    String(intervalSeconds),
  );

  return (
    <div className="polling-footer" data-testid="polling-footer">
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
