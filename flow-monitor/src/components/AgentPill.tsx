import { useTranslation } from "../i18n";
import { AXIS_LABEL, ROLE_TO_COLOR, type Role } from "../agentPalette";

interface AgentPillProps {
  role: Role;
}

/**
 * Pure presentational pill showing the active agent role.
 * Label from t("role.<key>"). Colors from CSS tokens scoped via
 * [data-color="<name>"] attribute selectors in agent-palette.css (D4).
 * Axis sub-badge rendered only for reviewer-* roles (AXIS_LABEL !== null).
 * Only hook is useTranslation(); no useEffect, no IPC.
 */
export function AgentPill({ role }: AgentPillProps) {
  const { t } = useTranslation();
  const color = ROLE_TO_COLOR[role];
  const axisLabel = AXIS_LABEL[role];

  return (
    <span className="agent-pill" data-role={role} data-color={color}>
      <span className="agent-pill__dot" />
      {t(`role.${role}`)}
      {axisLabel !== null && (
        <span className="agent-pill__axis">{axisLabel}</span>
      )}
    </span>
  );
}
