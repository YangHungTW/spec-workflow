/**
 * NotesTimeline — renders the STATUS Notes timeline for a scaff feature.
 *
 * Ordering: newest-first (AC9.i). The component sorts a copy of the input
 * descending by date string. ISO-8601 date strings (YYYY-MM-DD) sort
 * correctly with a plain string compare; other formats will sort
 * lexicographically. The sort is O(n log n) — safe for the B1 ceiling of
 * <100 entries without virtualisation (reviewer-performance documented assumption).
 *
 * No truncation: all entries are rendered. If this grows beyond ~1000 entries
 * in a future release, add windowing (e.g. react-window) at that point.
 *
 * Stub note (T21): the `notes` prop is wired with a placeholder empty array
 * in CardDetail until the IPC `read_artefact` → status_parse integration
 * lands in a later task. The component itself is production-ready.
 *
 * i18n note: Notes content is verbatim from the markdown file (AC9.c) and is
 * NOT passed through useTranslation — the date, role, and message are rendered
 * as-is. This is an explicit carve-out from the i18n discipline.
 *
 * T12 (AC11): role span receives inline color via normaliseRoleLabel +
 * ROLE_TO_COLOR. Only the colour changes; font-weight, italic, and layout
 * are preserved (R11 verbatim).
 */

import type { Role } from "../agentPalette";
import { ROLE_TO_COLOR } from "../agentPalette";

export interface NoteEntry {
  /** ISO-8601 date string from the STATUS Notes line — rendered verbatim (AC9.c). */
  date: string;
  /** Role name as written in the notes file (e.g. "Developer", "PM"). */
  role: string;
  /** Message text after the role separator. */
  message: string;
}

interface NotesTimelineProps {
  notes: NoteEntry[];
}

/** All 10 canonical role keys for O(1) membership lookup. */
const ROLE_SET: ReadonlySet<string> = new Set<Role>([
  "pm",
  "architect",
  "tpm",
  "developer",
  "designer",
  "qa-analyst",
  "qa-tester",
  "reviewer-security",
  "reviewer-performance",
  "reviewer-style",
]);

/**
 * Normalise a free-form role string from STATUS Notes into a canonical Role key.
 *
 * Strategy (AC11 spec):
 *   1. Lowercase the input.
 *   2. Strip parentheses so "reviewer (security)" becomes "reviewer security".
 *   3. Replace one or more whitespace chars with a single "-".
 *   4. Collapse repeated dashes that may arise from adjacent parens/spaces.
 *   5. Trim leading/trailing dashes.
 *   6. Return null if the result is not one of the 10 known Role keys.
 *
 * Examples:
 *   "Developer"           → "developer"
 *   "PM"                  → "pm"
 *   "Reviewer (security)" → "reviewer-security"
 *   "reviewer-security"   → "reviewer-security"
 *   "REVIEWER-SECURITY"   → "reviewer-security"
 *   "UnknownRole"         → null
 */
function normaliseRoleLabel(raw: string): Role | null {
  const normalised = raw
    .toLowerCase()
    .replace(/[()]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-{2,}/g, "-")
    .replace(/^-|-$/g, "");
  if (ROLE_SET.has(normalised)) {
    return normalised as Role;
  }
  return null;
}

/**
 * NotesTimeline renders an ordered list of note entries, newest first.
 *
 * Semantic HTML: <ol> with one <li> per entry containing:
 *   <time>{date}</time> <span>{role}</span> <span>{message}</span>
 *
 * No table, no complex grid — plain list per T21 spec.
 */
export function NotesTimeline({ notes }: NotesTimelineProps) {
  // Sort a copy descending by date string (ISO-8601 sorts correctly as strings).
  // Caller may pre-sort, but this ensures correctness regardless of input order.
  const sorted = [...notes].sort((a, b) =>
    b.date.localeCompare(a.date),
  );

  return (
    <ol
      className="notes-timeline"
      data-testid="notes-timeline"
      aria-label="Notes timeline"
    >
      {sorted.map((entry, idx) => {
        const role = normaliseRoleLabel(entry.role);
        const roleStyle =
          role !== null
            ? { color: `var(--agent-${ROLE_TO_COLOR[role]}-dot)` }
            : undefined;
        return (
          <li
            key={`${entry.date}-${entry.role}-${idx}`}
            className="notes-timeline__entry"
          >
            <time dateTime={entry.date} className="notes-timeline__date">
              {entry.date}
            </time>
            {" "}
            <span className="notes-timeline__role" style={roleStyle}>
              {entry.role}
            </span>
            {" — "}
            <span className="notes-timeline__message">{entry.message}</span>
          </li>
        );
      })}
    </ol>
  );
}
