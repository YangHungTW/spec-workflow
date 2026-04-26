/**
 * artifactStore — assertSafeArgs validation tests.
 *
 * Covers the security-must fix (W1 review):
 *   - repoPath must be non-empty; empty/blank throws.
 *   - slug must be non-empty; empty/blank throws.
 *   - slug containing / throws.
 *   - slug containing \ throws.
 *   - slug containing .. throws.
 *   - valid (repoPath, slug) pair does not throw in useArtifactChanges.
 *   - valid (repoPath, slug) pair does not throw in useTaskProgress.
 *
 * Per .claude/rules/reviewer/security.md check 3: validate at first boundary.
 */

import { describe, it, expect, vi } from "vitest";
import { renderHook } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks — must be declared before imports per vitest hoisting rules.
// ---------------------------------------------------------------------------

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn().mockResolvedValue(() => {}),
}));

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue(""),
}));

// ---------------------------------------------------------------------------
// Imports — after mocks.
// ---------------------------------------------------------------------------
import { useArtifactChanges, useTaskProgress } from "../artifactStore";

// ---------------------------------------------------------------------------
// assertSafeArgs — tested indirectly via hook entry points.
// ---------------------------------------------------------------------------

describe("useArtifactChanges — input validation at hook entry", () => {
  it("throws when repoPath is empty string", () => {
    expect(() => renderHook(() => useArtifactChanges("", "valid-slug"))).toThrow(
      /repoPath must be non-empty/,
    );
  });

  it("throws when repoPath is blank (whitespace only)", () => {
    expect(() =>
      renderHook(() => useArtifactChanges("   ", "valid-slug")),
    ).toThrow(/repoPath must be non-empty/);
  });

  it("throws when slug is empty string", () => {
    expect(() =>
      renderHook(() => useArtifactChanges("/repo/path", "")),
    ).toThrow(/slug must be non-empty/);
  });

  it("throws when slug is blank (whitespace only)", () => {
    expect(() =>
      renderHook(() => useArtifactChanges("/repo/path", "   ")),
    ).toThrow(/slug must be non-empty/);
  });

  it("throws when slug contains /", () => {
    expect(() =>
      renderHook(() => useArtifactChanges("/repo/path", "bad/slug")),
    ).toThrow(/slug contains forbidden chars/);
  });

  it("throws when slug contains \\", () => {
    expect(() =>
      renderHook(() => useArtifactChanges("/repo/path", "bad\\slug")),
    ).toThrow(/slug contains forbidden chars/);
  });

  it("throws when slug contains ..", () => {
    expect(() =>
      renderHook(() => useArtifactChanges("/repo/path", "../../etc/passwd")),
    ).toThrow(/slug contains forbidden chars/);
  });

  it("does not throw for a valid (repoPath, slug) pair", () => {
    expect(() =>
      renderHook(() =>
        useArtifactChanges("/repo/path", "20260426-flow-monitor-graph-view"),
      ),
    ).not.toThrow();
  });
});

describe("useTaskProgress — input validation at hook entry", () => {
  it("throws when repoPath is empty string", () => {
    expect(() => renderHook(() => useTaskProgress("", "valid-slug"))).toThrow(
      /repoPath must be non-empty/,
    );
  });

  it("throws when slug contains /", () => {
    expect(() =>
      renderHook(() => useTaskProgress("/repo/path", "bad/slug")),
    ).toThrow(/slug contains forbidden chars/);
  });

  it("throws when slug contains ..", () => {
    expect(() =>
      renderHook(() => useTaskProgress("/repo/path", "../escape")),
    ).toThrow(/slug contains forbidden chars/);
  });

  it("does not throw for a valid (repoPath, slug) pair", () => {
    expect(() =>
      renderHook(() => useTaskProgress("/repo/path", "20260426-my-feature")),
    ).not.toThrow();
  });
});
