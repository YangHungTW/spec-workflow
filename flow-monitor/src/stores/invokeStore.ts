/**
 * invokeStore — renderer-side dispatch wrapper + in-flight set.
 *
 * Design decisions (D6):
 *   - Single dispatch path for all write surfaces: ActionStrip, CommandPalette,
 *     SendPanel, compact-panel Next button.
 *   - classify() is imported from the T109-generated command_taxonomy.ts so the
 *     renderer and Rust share a single source of truth for SAFE/WRITE/DESTROY.
 *   - DESTROY commands open ConfirmModal (B2: this branch is unreachable because
 *     no B2 caller emits a DESTROY command; the branch exists for B3 wiring).
 *   - In-flight lock is per-(repo, slug) tuple, held in process memory only (R7);
 *     not persisted to disk (AC7.c). Cross-window state is synchronised via the
 *     in_flight_changed Tauri event emitted by lock.rs.
 *   - Terminal-spawn fallback: if outcome === "failed", retry immediately with
 *     delivery: "clipboard" and show error toast (AC4.c, D6).
 *   - No new state-library dependency — implemented as a React hook matching
 *     the sessionStore / themeStore shape (useState + useEffect + useCallback).
 */

import { useState, useEffect, useCallback, useRef } from "react";
import { invoke, type InvokeArgs } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { classify } from "../generated/command_taxonomy";

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/** Delivery method for a write command — matches the Rust DeliveryMethod enum. */
export type Delivery = "terminal" | "clipboard" | "pipe";

/**
 * Entry point that triggered the dispatch — matches the Rust EntryPoint enum.
 * Values must stay in sync with audit.rs's field-validation list (D7).
 */
export type EntryPoint =
  | "card-action"
  | "card-detail"
  | "palette"
  | "context-menu"
  | "compact-panel";

/** Outcome variants returned by invoke_command (Rust ipc.rs). */
export type InvokeOutcome = "spawned" | "copied" | "failed";

/** Response shape from the invoke_command Tauri command. */
export interface InvokeResult {
  outcome: InvokeOutcome;
  /** Tab-separated audit line written by audit.rs (informational; renderer may ignore). */
  audit_line?: string;
}

/**
 * InvokeStore — public surface consumed by ActionStrip, CommandPalette, etc.
 *
 * inFlight: Set of composite keys `"${repo}\x00${slug}"` for O(1) membership.
 * preflightCommand / preflightSlug: non-null while PreflightToast is visible.
 */
export interface InvokeStore {
  /** Keys of the form `"${repo}\x00${slug}"` currently in flight. */
  inFlight: Set<string>;
  /** Non-null for 3s after a terminal-spawn succeeds; drives PreflightToast. */
  preflightCommand: string | null;
  preflightSlug: string | null;
  dispatch(
    command: string,
    slug: string,
    repo: string,
    entry: EntryPoint,
    delivery: Delivery,
  ): Promise<void>;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/** Stable composite key for (repo, slug) — uses NUL as separator because
 *  repo paths are filesystem strings (may contain any printable char) while
 *  slugs are ASCII per B1 discipline (designer note 11). */
function inFlightKey(repo: string, slug: string): string {
  return `${repo}\x00${slug}`;
}

/** Shape of the in_flight_changed Tauri event payload (lock.rs → renderer). */
interface InFlightChangedPayload {
  locks: [string, string][];
  timestamp: number;
}

/** Shape of the audit_appended Tauri event payload. */
interface AuditAppendedPayload {
  repo: string;
  line: string;
}

/** Shape of the session_advanced Tauri event payload. */
interface SessionAdvancedPayload {
  repo: string;
  slug: string;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * useInvokeStore — React hook exposing the invokeStore surface.
 *
 * Subscribes to three Tauri events on mount; unsubscribes on unmount.
 * Intended to be called once per root component (App.tsx) and passed down
 * via props or a context, matching B1's single-instance store convention.
 */
export function useInvokeStore(): InvokeStore {
  const [inFlight, setInFlight] = useState<Set<string>>(new Set());
  const [preflightCommand, setPreflightCommand] = useState<string | null>(null);
  const [preflightSlug, setPreflightSlug] = useState<string | null>(null);

  // Stable ref so the dispatch callback can read current inFlight without
  // re-creating on every render (avoids stale-closure issues with useState).
  const inFlightRef = useRef<Set<string>>(inFlight);
  useEffect(() => {
    inFlightRef.current = inFlight;
  }, [inFlight]);

  // ------------------------------------------------------------------
  // Tauri event subscriptions
  // ------------------------------------------------------------------
  useEffect(() => {
    const unlisteners: Array<() => void> = [];

    // in_flight_changed — Rust emits this when lock state changes (AC7 R7).
    // Replaces the entire inFlight set so all windows stay consistent.
    listen<InFlightChangedPayload>("in_flight_changed", (event) => {
      const nextSet = new Set<string>(
        event.payload.locks.map(([repo, slug]) => inFlightKey(repo, slug)),
      );
      setInFlight(nextSet);
    }).then((fn) => unlisteners.push(fn));

    // audit_appended — informational; renderer can use to update AuditPanel.
    // invokeStore does not directly react to audit lines (AuditPanel is T[x]).
    listen<AuditAppendedPayload>("audit_appended", (_event) => {
      // Forwarding to AuditPanel is handled by the AuditPanel component
      // directly (it subscribes to this event itself). No-op here.
    }).then((fn) => unlisteners.push(fn));

    // session_advanced — polling observed a STATUS.md mtime change; Rust
    // releases the lock server-side and emits this event so the renderer
    // can clear the matching inFlight entry. This is belt-and-braces: the
    // in_flight_changed event covers the same transition, but session_advanced
    // may arrive first from a different code path.
    listen<SessionAdvancedPayload>("session_advanced", (event) => {
      const key = inFlightKey(event.payload.repo, event.payload.slug);
      setInFlight((prev) => {
        if (!prev.has(key)) return prev;
        const next = new Set(prev);
        next.delete(key);
        return next;
      });
    }).then((fn) => unlisteners.push(fn));

    return () => {
      for (const fn of unlisteners) fn();
    };
  }, []);

  // ------------------------------------------------------------------
  // dispatch
  // ------------------------------------------------------------------
  const dispatch = useCallback(
    async (
      command: string,
      slug: string,
      repo: string,
      entry: EntryPoint,
      delivery: Delivery,
    ): Promise<void> => {
      // (a) Classify the command.
      const commandClass = classify(command);

      // (b) DESTROY → open ConfirmModal.
      // In B2 this branch is unreachable: no caller emits a DESTROY command.
      // The branch exists so B3 can wire entry points without changing this file.
      if (commandClass === "destroy") {
        // ConfirmModal wiring is deferred to B3. Defensive guard only.
        console.warn(
          "[invokeStore] DESTROY branch reached in B2 — no entry point should emit a destroy command",
        );
        return;
      }

      // (c) In-flight guard — prevent double-dispatch for the same (repo, slug).
      const key = inFlightKey(repo, slug);
      if (inFlightRef.current.has(key)) {
        // Toast "Action already in flight" — i18n key: toast.in_flight.
        // Toast rendering is handled by the component layer (T[x]); the store
        // exposes the state signal via inFlight so callers can disable buttons.
        console.info("[invokeStore] dispatch blocked — already in flight", {
          repo,
          slug,
        });
        return;
      }

      // (d) Optimistically add to inFlight before the IPC call so the UI
      // disables the button immediately (the in_flight_changed event from Rust
      // will confirm / overwrite this optimistic entry).
      setInFlight((prev) => {
        const next = new Set(prev);
        next.add(key);
        return next;
      });

      try {
        const result = await invoke<InvokeResult>("invoke_command", {
          repo,
          slug,
          command,
          delivery,
          entry_point: entry,
        } satisfies InvokeArgs);

        // (e) Terminal-spawn success → show PreflightToast for 3s (WRITE only).
        if (delivery === "terminal" && result.outcome === "spawned") {
          setPreflightCommand(command);
          setPreflightSlug(slug);
          setTimeout(() => {
            setPreflightCommand(null);
            setPreflightSlug(null);
          }, 3000);
        }

        // (f) Terminal-spawn failure → fallback to clipboard (AC4.c).
        // A second audit line is written server-side for the clipboard attempt
        // (AC6.b). The error toast key is toast.terminal_failed.
        if (result.outcome === "failed") {
          await invoke<InvokeResult>("invoke_command", {
            repo,
            slug,
            command,
            delivery: "clipboard" satisfies Delivery,
            entry_point: entry,
          } satisfies InvokeArgs);
          // Error toast signalling is left to the component layer; the store
          // has no direct toast API. Components observe preflightCommand === null
          // after a failed+retried dispatch as the signal to show the error toast.
        }
      } catch (err) {
        // IPC-level error (command handler panicked, Tauri webview error, etc.).
        // Remove the optimistic inFlight entry so the button re-enables.
        setInFlight((prev) => {
          const next = new Set(prev);
          next.delete(key);
          return next;
        });
        // Re-throw so the caller can handle or log.
        throw err;
      }
    },
    [],
  );

  return {
    inFlight,
    preflightCommand,
    preflightSlug,
    dispatch,
  };
}
