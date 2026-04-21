import { useEffect } from "react";
import { useTranslation } from "../i18n";

interface PreflightToastProps {
  command: string;
  slug: string;
  onDismiss: () => void;
}

/**
 * 3-second auto-dismissing toast shown in the toolbar after a command is
 * dispatched. Informational only — the command is already in-flight (AC5.c).
 * Click-to-dismiss also supported for immediate user feedback.
 */
export function PreflightToast({ command, slug, onDismiss }: PreflightToastProps) {
  const { t } = useTranslation();

  useEffect(() => {
    const timerId = setTimeout(onDismiss, 3000);
    return () => {
      clearTimeout(timerId);
    };
  }, [onDismiss]);

  const body = t("toast.preflight")
    .replace("{command}", command)
    .replace("{slug}", slug);

  return (
    <div
      role="status"
      aria-live="polite"
      className="preflight-toast"
      onClick={onDismiss}
    >
      {body}
    </div>
  );
}
