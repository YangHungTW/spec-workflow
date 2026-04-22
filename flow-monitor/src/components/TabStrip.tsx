import { useEffect, useRef } from "react";
import { useTranslation } from "../i18n";

export interface TabDefinition {
  id: string;
  labelKey: string;
  exists: boolean;
}

interface TabStripProps {
  tabs: TabDefinition[];
  activeId: string;
  onSelect: (id: string) => void;
}

/**
 * TabStrip — horizontally scrollable 9-tab strip for CardDetail.
 *
 * AC9.g: overflow-x: auto so the strip scrolls rather than wraps when tabs
 * exceed the available horizontal space. Active tab auto-scrolls into view on
 * every activeId change via scrollIntoView({ behavior: "smooth", ... }).
 *
 * AC9.d: tabs with exists=false are greyed out and carry a "not yet generated"
 * tooltip. They are still rendered and clickable so users can see what artefacts
 * are expected; styling distinguishes presence from absence.
 *
 * No overflow menu, no wrap, no collapse — per AC9.g constraint.
 */
export function TabStrip({ tabs, activeId, onSelect }: TabStripProps) {
  const { t } = useTranslation();

  // One ref per tab; only the active tab's ref is used for scrollIntoView.
  // Using a Map keyed by id avoids the O(n) array search on each render.
  const tabRefs = useRef<Map<string, HTMLButtonElement>>(new Map());

  useEffect(() => {
    const el = tabRefs.current.get(activeId);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" });
    }
  }, [activeId]);

  return (
    <div
      role="tablist"
      style={{
        display: "flex",
        flexDirection: "row",
        flexWrap: "nowrap",
        overflowX: "auto",
        // Prevent the strip from growing its cross-axis to fill the parent.
        alignItems: "center",
      }}
    >
      {tabs.map((tab) => {
        const isActive = tab.id === activeId;
        return (
          <button
            key={tab.id}
            type="button"
            role="tab"
            aria-selected={isActive}
            data-tab-id={tab.id}
            data-exists={String(tab.exists)}
            title={tab.exists ? undefined : t("tab.notYetGenerated")}
            className={[
              "tab-strip__tab",
              isActive ? "tab-strip__tab--active" : "",
              tab.exists ? "" : "tab-strip__tab--missing",
            ]
              .filter(Boolean)
              .join(" ")}
            ref={(el) => {
              if (el) {
                tabRefs.current.set(tab.id, el);
              } else {
                tabRefs.current.delete(tab.id);
              }
            }}
            aria-disabled={!tab.exists}
            tabIndex={tab.exists ? 0 : -1}
            onClick={() => { if (!tab.exists) return; onSelect(tab.id); }}
          >
            {t(tab.labelKey)}
          </button>
        );
      })}
    </div>
  );
}
