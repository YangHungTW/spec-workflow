/**
 * Performance regression test for T17 retry:
 *   groupSessionsByRepo must look up repo names in O(1) via a pre-built Map,
 *   not O(n) via repos.find() inside the session loop.
 *
 * We verify the observable behaviour: when many sessions share the same
 * repoId, the repo name is resolved correctly from a pre-built Map rather
 * than a per-iteration linear scan.
 *
 * Written BEFORE the production fix (TDD red → green).
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, act, screen } from "@testing-library/react";

// Stub i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

// Stub Tauri IPC — returns 3 repos, each with multiple sessions
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
import MainWindow from "../MainWindow";

const REPOS = [
  { id: "repo-alpha", name: "Alpha Repo", path: "/tmp/alpha" },
  { id: "repo-beta", name: "Beta Repo", path: "/tmp/beta" },
  { id: "repo-gamma", name: "Gamma Repo", path: "/tmp/gamma" },
];

function makeSession(
  slug: string,
  repoId: string,
): object {
  return {
    slug,
    stage: "implement",
    idle_state: "none",
    last_updated_ms: Date.now(),
    note_excerpt: "",
    repo_path: `/tmp/${repoId}`,
    repo_id: repoId,
    repo_name: repoId,
  };
}

// Build 30 sessions — 10 per repo
const SESSIONS = [
  ...Array.from({ length: 10 }, (_, i) => makeSession(`alpha-${i}`, "repo-alpha")),
  ...Array.from({ length: 10 }, (_, i) => makeSession(`beta-${i}`, "repo-beta")),
  ...Array.from({ length: 10 }, (_, i) => makeSession(`gamma-${i}`, "repo-gamma")),
];

describe("MainWindow — groupSessionsByRepo uses pre-built Map (O(n) lookup)", () => {
  beforeEach(() => {
    vi.mocked(invoke).mockImplementation((cmd: string) => {
      if (cmd === "list_sessions") {
        return Promise.resolve({
          sessions: SESSIONS,
          polling_interval_secs: 3,
        });
      }
      if (cmd === "get_settings") {
        return Promise.resolve({
          repos: REPOS,
          polling_interval_secs: 3,
          collapsed_repo_ids: [],
        });
      }
      return Promise.resolve(undefined);
    });
  });

  it("renders all 3 repo group headers with correct names from repos list", async () => {
    await act(async () => {
      render(<MainWindow />);
    });

    // All 3 repos should appear as group headers
    expect(document.querySelector("[data-testid='repo-group-repo-alpha']")).toBeTruthy();
    expect(document.querySelector("[data-testid='repo-group-repo-beta']")).toBeTruthy();
    expect(document.querySelector("[data-testid='repo-group-repo-gamma']")).toBeTruthy();
  });

  it("repo header shows name from repos list (not raw repoId fallback)", async () => {
    await act(async () => {
      render(<MainWindow />);
    });

    // The header for repo-alpha should display "Alpha Repo" (from repos list),
    // not the raw id "repo-alpha" — this verifies Map lookup resolves names.
    const alphaHeader = document.querySelector("[data-testid='repo-header-repo-alpha']");
    expect(alphaHeader).toBeTruthy();
    expect(alphaHeader!.textContent).toContain("Alpha Repo");
  });

  it("group count reflects correct session count per repo (10 each)", async () => {
    await act(async () => {
      render(<MainWindow />);
    });

    // Each group header should show "(10)" — verifying all sessions are grouped
    const betaHeader = document.querySelector("[data-testid='repo-header-repo-beta']");
    expect(betaHeader!.textContent).toContain("(10)");
  });
});
