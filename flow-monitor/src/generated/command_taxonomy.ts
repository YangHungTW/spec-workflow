/**
 * command_taxonomy.ts — placeholder for the T109 build.rs generated file.
 *
 * T109 (parallel with T110 in W2) generates this file via build.rs from the
 * Rust command_taxonomy.rs source of truth. At W2 merge time, T109's version
 * replaces this placeholder. The export signatures below match the expected
 * interface so TypeScript can type-check invokeStore.ts during T110's local
 * build verification.
 *
 * DO NOT ADD commands here — the authoritative list lives in
 * src-tauri/src/command_taxonomy.rs (T109).
 */

/** Commands that only read state — no mutation, no confirmation required. */
export const SAFE = [] as const;

/** Commands that mutate spec-workflow state — require PreflightToast on terminal spawn. */
export const WRITE = [] as const;

/** Commands that are destructive — require ConfirmModal before dispatch (B3 entry points). */
export const DESTROY = [] as const;

export type SafeCommand = (typeof SAFE)[number];
export type WriteCommand = (typeof WRITE)[number];
export type DestroyCommand = (typeof DESTROY)[number];

export type CommandClass = "safe" | "write" | "destroy";

/**
 * classify — pure function mapping a command string to its class.
 * Returns null for unknown commands (not in any allow-list).
 */
export function classify(command: string): CommandClass | null {
  if ((SAFE as readonly string[]).includes(command)) return "safe";
  if ((WRITE as readonly string[]).includes(command)) return "write";
  if ((DESTROY as readonly string[]).includes(command)) return "destroy";
  return null;
}
