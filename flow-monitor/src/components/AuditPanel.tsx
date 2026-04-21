import { useState, useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { useTranslation } from "../i18n";

// ---------------------------------------------------------------------------
// Types — mirror the Rust AuditLine struct (serde serialization shapes)
// ---------------------------------------------------------------------------

/** One audit log entry as returned by the get_audit_tail IPC command. */
export interface AuditLine {
  /** RFC 3339 / ISO 8601 timestamp string. */
  ts: string;
  /** Session slug. */
  slug: string;
  /** specflow command name (e.g. "implement"). */
  command: string;
  /** Entry-point that triggered the dispatch (kebab-case). */
  entry_point: string;
  /** Delivery mechanism (lowercase). */
  delivery: string;
  /** Result of the dispatch attempt (lowercase). */
  outcome: string;
}

/** Payload shape of the audit_appended Tauri event. */
interface AuditAppendedPayload {
  repo: string;
  line: AuditLine;
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export interface AuditPanelProps {
  /** Absolute path to the repository root. */
  repo: string;
  /** Max number of entries to fetch on mount (default 50). */
  limit?: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Format an ISO-8601 timestamp string for display.
 * Renders as "YYYY-MM-DD HH:MM:SS" in local time where available,
 * falling back to the raw string on parse failure.
 */
function formatTimestamp(ts: string): string {
  try {
    const d = new Date(ts);
    if (isNaN(d.getTime())) return ts;
    const pad = (n: number) => String(n).padStart(2, "0");
    return (
      `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ` +
      `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
    );
  } catch {
    return ts;
  }
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * AuditPanel — Card Detail left-rail audit log section.
 *
 * On mount fetches the tail of the audit log via get_audit_tail IPC and
 * renders entries in reverse-chronological order (newest first). Subscribes
 * to audit_appended events so live dispatches appear at the top without
 * requiring a manual refresh.
 *
 * Read-only — no click or interaction targets per T105 scope.
 * Background uses --surface-subtle token per B2 reuse map (D10).
 */
export function AuditPanel({ repo, limit = 50 }: AuditPanelProps) {
  const { t } = useTranslation();
  const [entries, setEntries] = useState<AuditLine[]>([]);

  // Fetch initial tail on mount.
  useEffect(() => {
    invoke<AuditLine[]>("get_audit_tail", { repo, limit }).then((lines) => {
      setEntries(lines);
    }).catch((e: unknown) => {
      if (import.meta.env.DEV) console.error("get_audit_tail failed:", e);
    });
  }, [repo, limit]);

  // Subscribe to live audit_appended events; prepend new entries to the top.
  useEffect(() => {
    let unlisten: (() => void) | null = null;

    listen<AuditAppendedPayload>("audit_appended", (event) => {
      if (event.payload?.line) {
        setEntries((prev) => [event.payload.line, ...prev]);
      }
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      if (unlisten) {
        unlisten();
      }
    };
  }, []);

  return (
    <section
      className="audit-panel"
      data-testid="audit-panel"
      style={{ background: "var(--surface-subtle)" }}
    >
      <h3 className="audit-panel__title">{t("audit.panel.title")}</h3>
      <ol className="audit-panel__list">
        {entries.map((entry, idx) => (
          <li
            key={`${entry.ts}-${idx}`}
            className="audit-panel__entry"
            data-testid="audit-entry"
          >
            <time
              className="audit-panel__ts"
              dateTime={entry.ts}
            >
              {formatTimestamp(entry.ts)}
            </time>
            <span className="audit-panel__command">{entry.command}</span>
            <span className="audit-panel__entry-point">{entry.entry_point}</span>
            <span className="audit-panel__via">{t("audit.entry.via")}</span>
            <span className="audit-panel__delivery">{entry.delivery}</span>
            <span className="audit-panel__outcome">{entry.outcome}</span>
          </li>
        ))}
      </ol>
    </section>
  );
}

export default AuditPanel;
