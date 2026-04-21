/**
 * SendPanel — 3-tab delivery strip for Card Detail, Screen 2.
 *
 * Tabs (D6):
 *   pipe           — disabled; deferred to future release. Tooltip is English
 *                    fixed text (no i18n key) per designer note 11.
 *   terminal-spawn — default selected (AC3.b). Send calls dispatch with
 *                    delivery: 'terminal'.
 *   clipboard      — selectable. Send calls dispatch with delivery: 'clipboard'.
 *
 * Pipe tab is rendered but cannot be selected; its button carries the HTML
 * `disabled` attribute so the browser prevents interaction natively, and the
 * onClick guard below is a belt-and-braces defence.
 */

import { useState } from "react";
import type { InvokeStore, EntryPoint } from "../stores/invokeStore";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type TabId = "terminal-spawn" | "clipboard" | "pipe";

interface Tab {
  id: TabId;
  label: string;
  disabled?: boolean;
  disabledTooltip?: string;
}

const TABS: Tab[] = [
  {
    id: "pipe",
    label: "pipe",
    disabled: true,
    // English fixed; no i18n key per designer note 11 on tooltip brevity.
    disabledTooltip: "Deferred to future release",
  },
  {
    id: "terminal-spawn",
    label: "terminal-spawn",
  },
  {
    id: "clipboard",
    label: "clipboard",
  },
];

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export interface SendPanelProps {
  command: string;
  slug: string;
  repo: string;
  entry: EntryPoint;
  invokeStore: InvokeStore;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function SendPanel({ command, slug, repo, entry, invokeStore }: SendPanelProps) {
  // terminal-spawn is the default selected tab per AC3.b.
  const [activeTabId, setActiveTabId] = useState<TabId>("terminal-spawn");
  const [bodyText, setBodyText] = useState("");

  function handleTabClick(tab: Tab) {
    // Disabled tabs (pipe) must not become active — guard against synthetic
    // fireEvent calls in tests and any future removal of the HTML disabled attr.
    if (tab.disabled) return;
    setActiveTabId(tab.id);
  }

  function handleSend() {
    // pipe tab is always disabled so activeTabId can never be 'pipe' here;
    // the conditional guards against future misuse.
    if (activeTabId === "pipe") return;
    const delivery = activeTabId === "terminal-spawn" ? "terminal" : "clipboard";
    void invokeStore.dispatch(command, slug, repo, entry, delivery);
  }

  return (
    <div data-testid="send-panel">
      {/* Tab strip */}
      <div role="tablist">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            type="button"
            role="tab"
            aria-selected={activeTabId === tab.id}
            disabled={tab.disabled}
            title={tab.disabled ? tab.disabledTooltip : undefined}
            onClick={() => handleTabClick(tab)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Panel body */}
      <div role="tabpanel">
        <textarea
          value={bodyText}
          onChange={(e) => setBodyText(e.target.value)}
          placeholder="Additional context (optional)"
        />
        <button
          type="button"
          onClick={handleSend}
          disabled={activeTabId === "pipe"}
        >
          Send
        </button>
      </div>
    </div>
  );
}
