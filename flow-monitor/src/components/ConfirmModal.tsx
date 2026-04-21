import { useTranslation } from "../i18n";

export interface ConfirmModalProps {
  command: string;
  slug: string;
  onCancel: () => void;
  onConfirm: () => void;
}

/**
 * ConfirmModal — DESTROY confirmation modal (Seam F / Screen 4).
 *
 * AC8.a: Enter keypress is intentionally INERT — does NOT trigger onConfirm
 * or onCancel. Only explicit button clicks are actionable. This prevents
 * accidental keyboard confirmation of a destructive action.
 *
 * Cancel button receives autoFocus on mount so the keyboard path defaults
 * to the safe action.
 *
 * B2 scaffold: no caller imports this component in B2. B3 wires it.
 */
export function ConfirmModal({
  command,
  slug,
  onCancel,
  onConfirm,
}: ConfirmModalProps) {
  const { t } = useTranslation();

  return (
    <div
      role="dialog"
      aria-modal="true"
      className="confirm-modal"
      data-testid="confirm-modal"
    >
      <div className="confirm-modal__content">
        <h2 className="confirm-modal__title">
          {t("modal.destroy.title")} {command} ({slug})
        </h2>

        <div className="confirm-modal__actions">
          {/* autoFocus ensures Cancel is the default keyboard target (safe action) */}
          <button
            type="button"
            className="confirm-modal__cancel"
            onClick={onCancel}
            // eslint-disable-next-line jsx-a11y/no-autofocus
            autoFocus
          >
            {t("modal.destroy.cancel")}
          </button>
          <button
            type="button"
            className="confirm-modal__confirm"
            onClick={onConfirm}
          >
            {t("modal.destroy.confirm")}
          </button>
        </div>
      </div>
    </div>
  );
}

export default ConfirmModal;
