import { useTranslation } from "../i18n";
import { type SortAxis } from "../stores/sessionStore";

export interface SortToolbarProps {
  sortAxis: SortAxis;
  onSortChange: (axis: SortAxis) => void;
}

/**
 * Sort axes — exactly 4 per AC7.c.
 * Order matches the design specification.
 */
export const SORT_AXES: SortAxis[] = [
  "LastUpdatedDesc",
  "Stage",
  "SlugAZ",
  "StalledFirst",
];

/**
 * SortToolbar — top toolbar with sort dropdown.
 *
 * AC7.b — default sort is LastUpdatedDesc
 * AC7.c — exactly 4 sort axes; reorder within one frame (no IPC round-trip)
 *
 * Pure presentational — state lifted to sessionStore via props.
 */
export function SortToolbar({ sortAxis, onSortChange }: SortToolbarProps) {
  const { t } = useTranslation();

  const axisLabels: Record<SortAxis, string> = {
    LastUpdatedDesc: t("sort.lastUpdatedDesc"),
    Stage: t("sort.stage"),
    SlugAZ: t("sort.slugAZ"),
    StalledFirst: t("sort.stalledFirst"),
  };

  return (
    <div className="sort-toolbar" data-testid="sort-toolbar">
      <label htmlFor="sort-select" className="sort-toolbar__label">
        {t("sort.label")}
      </label>
      <select
        id="sort-select"
        className="sort-toolbar__select"
        value={sortAxis}
        onChange={(e) => onSortChange(e.target.value as SortAxis)}
        data-testid="sort-select"
      >
        {SORT_AXES.map((axis) => (
          <option key={axis} value={axis}>
            {axisLabels[axis]}
          </option>
        ))}
      </select>
    </div>
  );
}

export default SortToolbar;
