/**
 * CommandPalette — overlay modal per Screen 3 (B2).
 *
 * Renders SAFE ∪ WRITE commands grouped into Control Actions and Specflow
 * Commands. The Destructive group is intentionally empty in B2: this component
 * imports only SAFE and WRITE from the generated taxonomy; DESTROY is never
 * imported so the T99 grep test can assert DESTROY names appear only in
 * command_taxonomy.ts.
 *
 * Props:
 *   open          — controls visibility; renders null when false.
 *   onClose       — called on Esc, backdrop click, or after a command is dispatched.
 *   focusedSession — the session context passed to invokeStore.dispatch(); if
 *                   absent, dispatch is a no-op (palette may still open, e.g. from ⌘K
 *                   when no session card is focused).
 *
 * Keyboard:
 *   ArrowUp / ArrowDown — move focus through the command list.
 *   Enter — dispatch the focused command and close.
 *   Escape — close without dispatching.
 *
 * No shell invocation: all side effects go through invokeStore.dispatch().
 */

import { useState, useEffect, useCallback } from "react";
import { useTranslation } from "../i18n";
import { SAFE, WRITE } from "../generated/command_taxonomy";
import { useInvokeStore } from "../stores/invokeStore";
import type { SessionState } from "../stores/sessionStore";

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface CommandPaletteProps {
  open: boolean;
  onClose: () => void;
  focusedSession?: SessionState;
}

// ---------------------------------------------------------------------------
// Command list — SAFE ∪ WRITE only; DESTROY is excluded by design (AC5.b).
// ---------------------------------------------------------------------------

/** All commands available in the palette, in display order. */
const ALL_COMMANDS: ReadonlyArray<string> = [...SAFE, ...WRITE];

/** Set used for O(1) WRITE membership checks in the render loop. */
const WRITE_SET: Set<string> = new Set(WRITE);

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function CommandPalette({ open, onClose, focusedSession }: CommandPaletteProps) {
  const { t } = useTranslation();
  const invokeStore = useInvokeStore();

  // Index of the keyboard-focused command item (0-based).
  const [focusedIndex, setFocusedIndex] = useState(0);

  // Reset keyboard focus to the first item whenever the palette opens.
  useEffect(() => {
    if (open) {
      setFocusedIndex(0);
    }
  }, [open]);

  // Dispatch the command at the given index and close the palette.
  const selectCommand = useCallback(
    (index: number) => {
      const cmd = ALL_COMMANDS[index];
      if (cmd === undefined) return;

      if (focusedSession) {
        void invokeStore.dispatch(
          cmd,
          focusedSession.slug,
          focusedSession.repoPath,
          "palette",
          "terminal",
        );
      }
      onClose();
    },
    [focusedSession, invokeStore, onClose],
  );

  // Keyboard handler attached to the palette container.
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLDivElement>) => {
      switch (e.key) {
        case "Escape":
          e.preventDefault();
          onClose();
          break;

        case "ArrowDown":
          e.preventDefault();
          setFocusedIndex((prev) => (prev + 1) % ALL_COMMANDS.length);
          break;

        case "ArrowUp":
          e.preventDefault();
          setFocusedIndex(
            (prev) => (prev - 1 + ALL_COMMANDS.length) % ALL_COMMANDS.length,
          );
          break;

        case "Enter":
          e.preventDefault();
          selectCommand(focusedIndex);
          break;

        default:
          break;
      }
    },
    [focusedIndex, onClose, selectCommand],
  );

  if (!open) {
    return null;
  }

  return (
    <>
      {/* Backdrop — click outside to close */}
      <div
        className="command-palette__backdrop"
        data-testid="command-palette-backdrop"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Palette modal */}
      <div
        className="command-palette"
        data-testid="command-palette"
        role="dialog"
        aria-modal="true"
        aria-label={t("palette.title")}
        tabIndex={-1}
        onKeyDown={handleKeyDown}
      >
        {/* Command list — SAFE commands first, then WRITE commands */}
        <ul
          className="command-palette__list"
          role="listbox"
          aria-label={t("palette.title")}
        >
          {ALL_COMMANDS.map((cmd, index) => {
            const isWrite = WRITE_SET.has(cmd);
            const isFocused = index === focusedIndex;

            return (
              <li
                key={cmd}
                className={`command-palette__item${isFocused ? " command-palette__item--focused" : ""}`}
                data-testid="palette-item"
                data-focused={isFocused ? "true" : "false"}
                role="option"
                aria-selected={isFocused}
                onClick={() => {
                  setFocusedIndex(index);
                  selectCommand(index);
                }}
              >
                <span className="command-palette__item-name">{cmd}</span>
                {isWrite && (
                  <span
                    className="command-palette__write-pill"
                    data-testid="write-pill"
                    aria-label={t("palette.pill.write")}
                  >
                    {t("palette.pill.write")}
                  </span>
                )}
              </li>
            );
          })}
        </ul>
      </div>
    </>
  );
}
