/**
 * Tests for T24: CompactPanel view
 *
 * AC10.a — one row per active session: coloured-dot · slug · stage-pill · relative-time
 * AC10.b — no "Send instruction" / "Quick advance" buttons (B2 boundary guard)
 * AC10.e — "Open main" affordance at the bottom
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import CompactPanel from "../../views/CompactPanel";

// Mock i18n — returns key as value
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

// Mock StagePill — renders stage key as text so tests can query it
vi.mock("../StagePill", () => ({
  StagePill: ({ stage }: { stage: string }) => (
    <span data-testid="stage-pill">{stage}</span>
  ),
}));

// Mock Tauri IPC for focus_main_window
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";

const mockInvoke = vi.mocked(invoke);

/** Minimal session fixture matching CompactPanel's expected prop shape. */
interface SessionRow {
  key: string;
  slug: string;
  stage: string;
  relativeTime: string;
  idleState: "none" | "stale" | "stalled";
}

const THREE_SESSIONS: SessionRow[] = [
  { key: "s1", slug: "feature-auth", stage: "implement", relativeTime: "2m ago", idleState: "none" },
  { key: "s2", slug: "fix-login-bug", stage: "verify", relativeTime: "10m ago", idleState: "stale" },
  { key: "s3", slug: "update-docs", stage: "plan", relativeTime: "1h ago", idleState: "stalled" },
];

describe("CompactPanel", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
  });

  it("renders one row per session (3 sessions → 3 rows)", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    const rows = screen.getAllByRole("listitem");
    expect(rows).toHaveLength(3);
  });

  it("each row shows the session slug", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    expect(screen.getByText("feature-auth")).toBeTruthy();
    expect(screen.getByText("fix-login-bug")).toBeTruthy();
    expect(screen.getByText("update-docs")).toBeTruthy();
  });

  it("each row shows the stage pill", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    const pills = screen.getAllByTestId("stage-pill");
    expect(pills).toHaveLength(3);
    expect(pills[0].textContent).toBe("implement");
    expect(pills[1].textContent).toBe("verify");
    expect(pills[2].textContent).toBe("plan");
  });

  it("each row shows relative time", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    expect(screen.getByText("2m ago")).toBeTruthy();
    expect(screen.getByText("10m ago")).toBeTruthy();
    expect(screen.getByText("1h ago")).toBeTruthy();
  });

  it("each row has a coloured status dot", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    const dots = screen.getAllByTestId("session-dot");
    expect(dots).toHaveLength(3);
  });

  it("status dot reflects idle state via data-idle-state attribute", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    const dots = screen.getAllByTestId("session-dot");
    expect(dots[0]).toHaveAttribute("data-idle-state", "none");
    expect(dots[1]).toHaveAttribute("data-idle-state", "stale");
    expect(dots[2]).toHaveAttribute("data-idle-state", "stalled");
  });

  it("renders 'Open main' button at the bottom via t('btn.openMain')", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    expect(screen.getByRole("button", { name: "btn.openMain" })).toBeTruthy();
  });

  it("'Open main' button invokes focus_main_window IPC", async () => {
    mockInvoke.mockResolvedValueOnce(undefined);
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    fireEvent.click(screen.getByRole("button", { name: "btn.openMain" }));
    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("focus_main_window");
    });
  });

  it("B2 guard: no 'Send instruction' button present", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    expect(screen.queryByText(/send instruction/i)).toBeNull();
  });

  it("B2 guard: no 'Quick advance' button present", () => {
    render(<CompactPanel sessions={THREE_SESSIONS} />);
    expect(screen.queryByText(/quick advance/i)).toBeNull();
  });

  it("renders empty state row when sessions is empty", () => {
    render(<CompactPanel sessions={[]} />);
    const rows = screen.queryAllByRole("listitem");
    expect(rows).toHaveLength(0);
  });
});
