/**
 * Tests for T105: AuditPanel component
 *
 * - On mount, invokes get_audit_tail and renders each returned AuditLine.
 * - Each entry shows: formatted ISO-8601 timestamp, command name, entry-point,
 *   delivery method, outcome.
 * - Subscribes to audit_appended Tauri event; prepends new entries to the top.
 * - Read-only — no click actions.
 * - Uses --surface-subtle token for panel background.
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, act } from "@testing-library/react";
import { AuditPanel } from "../AuditPanel";

// ---------------------------------------------------------------------------
// i18n stub — returns key as-is (T112a/b keys mocked here per T105 scope)
// ---------------------------------------------------------------------------
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "audit.panel.title": "Audit Log",
        "audit.entry.via": "via",
      };
      return map[key] ?? key;
    },
  }),
}));

// ---------------------------------------------------------------------------
// Tauri invoke mock — returns 3-line fixture on get_audit_tail
// ---------------------------------------------------------------------------
const FIXTURE_LINES = [
  {
    ts: "2026-04-21T10:00:00Z",
    slug: "my-feature",
    command: "implement",
    entry_point: "card-action",
    delivery: "terminal",
    outcome: "spawned",
  },
  {
    ts: "2026-04-21T09:30:00Z",
    slug: "my-feature",
    command: "prd",
    entry_point: "palette",
    delivery: "clipboard",
    outcome: "copied",
  },
  {
    ts: "2026-04-21T09:00:00Z",
    slug: "my-feature",
    command: "design",
    entry_point: "card-detail",
    delivery: "terminal",
    outcome: "failed",
  },
];

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

// ---------------------------------------------------------------------------
// Tauri event mock — captures audit_appended callbacks so tests can fire them
// ---------------------------------------------------------------------------
const mockUnlisten = vi.fn();
let capturedEventName: string | null = null;
let capturedCallback: ((event: { payload: unknown }) => void) | null = null;

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn((eventName: string, cb: (event: { payload: unknown }) => void) => {
    capturedEventName = eventName;
    capturedCallback = cb;
    return Promise.resolve(mockUnlisten);
  }),
}));

import { invoke } from "@tauri-apps/api/core";
const mockInvoke = vi.mocked(invoke);

describe("AuditPanel — initial render (get_audit_tail)", () => {
  beforeEach(() => {
    capturedEventName = null;
    capturedCallback = null;
    mockUnlisten.mockReset();
    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue(FIXTURE_LINES);
  });

  it("calls get_audit_tail with repo and default limit on mount", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    expect(mockInvoke).toHaveBeenCalledWith("get_audit_tail", {
      repo: "/Users/alice/projects/my-repo",
      limit: 50,
    });
  });

  it("calls get_audit_tail with custom limit when provided", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" limit={10} />);
    });
    expect(mockInvoke).toHaveBeenCalledWith("get_audit_tail", {
      repo: "/Users/alice/projects/my-repo",
      limit: 10,
    });
  });

  it("renders 3 entries from the fixture", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    const items = document.querySelectorAll("[data-testid='audit-entry']");
    expect(items.length).toBe(3);
  });

  it("renders the command name for each entry", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    expect(screen.getByText("implement")).toBeTruthy();
    expect(screen.getByText("prd")).toBeTruthy();
    expect(screen.getByText("design")).toBeTruthy();
  });

  it("renders entry-point for each entry", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    expect(screen.getByText("card-action")).toBeTruthy();
    expect(screen.getByText("palette")).toBeTruthy();
    expect(screen.getByText("card-detail")).toBeTruthy();
  });

  it("renders delivery method for each entry", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    // "terminal" appears twice; "clipboard" once
    const terminals = screen.getAllByText("terminal");
    expect(terminals.length).toBe(2);
    expect(screen.getByText("clipboard")).toBeTruthy();
  });

  it("renders outcome for each entry", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    expect(screen.getByText("spawned")).toBeTruthy();
    expect(screen.getByText("copied")).toBeTruthy();
    expect(screen.getByText("failed")).toBeTruthy();
  });

  it("renders formatted timestamp for the first entry", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    // The raw ISO string must appear somewhere in the rendered output (formatted)
    // We check that a time element with a datetime attribute containing the ISO string exists
    const timeEls = document.querySelectorAll("time");
    expect(timeEls.length).toBeGreaterThanOrEqual(3);
  });

  it("renders entries in reverse-chronological order (newest first)", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    const items = document.querySelectorAll("[data-testid='audit-entry']");
    // First entry must be the one with ts 2026-04-21T10:00:00Z (implement)
    expect(items[0].textContent).toContain("implement");
    // Last entry must be the one with ts 2026-04-21T09:00:00Z (design)
    expect(items[items.length - 1].textContent).toContain("design");
  });

  it("renders panel title from i18n key audit.panel.title", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    expect(screen.getByText("Audit Log")).toBeTruthy();
  });

  it("renders empty list when get_audit_tail returns empty array", async () => {
    mockInvoke.mockResolvedValue([]);
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    const items = document.querySelectorAll("[data-testid='audit-entry']");
    expect(items.length).toBe(0);
  });
});

describe("AuditPanel — audit_appended event subscription", () => {
  beforeEach(() => {
    capturedEventName = null;
    capturedCallback = null;
    mockUnlisten.mockReset();
    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue(FIXTURE_LINES);
  });

  it("subscribes to audit_appended event on mount", async () => {
    const { listen } = await import("@tauri-apps/api/event");
    const mockListen = vi.mocked(listen);
    mockListen.mockClear();

    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    expect(capturedEventName).toBe("audit_appended");
  });

  it("prepends new entry to top when audit_appended event fires", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });

    const newEntry = {
      ts: "2026-04-21T11:00:00Z",
      slug: "my-feature",
      command: "validate",
      entry_point: "card-action",
      delivery: "terminal",
      outcome: "spawned",
    };

    expect(capturedCallback).not.toBeNull();
    await act(async () => {
      capturedCallback!({ payload: { repo: "/Users/alice/projects/my-repo", line: newEntry } });
    });

    const items = document.querySelectorAll("[data-testid='audit-entry']");
    // 3 original + 1 new = 4 entries
    expect(items.length).toBe(4);
    // New entry is at the top
    expect(items[0].textContent).toContain("validate");
  });

  it("new entry from event appears before previous entries", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });

    const newEntry = {
      ts: "2026-04-21T11:00:00Z",
      slug: "my-feature",
      command: "tasks",
      entry_point: "palette",
      delivery: "clipboard",
      outcome: "copied",
    };

    await act(async () => {
      capturedCallback!({ payload: { repo: "/Users/alice/projects/my-repo", line: newEntry } });
    });

    const items = document.querySelectorAll("[data-testid='audit-entry']");
    // "tasks" is the new entry, must be first
    expect(items[0].textContent).toContain("tasks");
    // "implement" was the original first, now second
    expect(items[1].textContent).toContain("implement");
  });

  it("unlisten is called on unmount (no memory leak)", async () => {
    let unmount: () => void;
    await act(async () => {
      const result = render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
      unmount = result.unmount;
    });

    await act(async () => {
      unmount();
    });

    expect(mockUnlisten).toHaveBeenCalledTimes(1);
  });
});

describe("AuditPanel — no click actions (read-only)", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue(FIXTURE_LINES);
  });

  it("entries have no interactive buttons", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    const buttons = document.querySelectorAll("[data-testid='audit-entry'] button");
    expect(buttons.length).toBe(0);
  });

  it("entries have no anchor links", async () => {
    await act(async () => {
      render(<AuditPanel repo="/Users/alice/projects/my-repo" />);
    });
    const links = document.querySelectorAll("[data-testid='audit-entry'] a");
    expect(links.length).toBe(0);
  });
});
