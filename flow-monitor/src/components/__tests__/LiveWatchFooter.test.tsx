/**
 * LiveWatchFooter — tests for AC15 and AC16.
 *
 * AC15: exactly one pip element + label "Live FS watch" (or i18n key);
 *       no numeric interval rendered; old polling-footer testid is absent.
 * AC16: pip turns grey and stops pulsing when watcher state is "errored";
 *       pip is running/pulsing when state is "running".
 *
 * Mocks declared before imports per vitest hoisting rules.
 */

import { describe, it, expect, vi } from "vitest";
import { render } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

// Stub i18n — sidebar.liveFsWatch key registered in T12; fall back here.
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "sidebar.liveFsWatch": "Live FS watch",
      };
      return map[key] ?? key;
    },
  }),
}));

// Capture watcher_status handlers.
type EventHandler = (event: { payload: unknown }) => void;
const _wsHandlers: EventHandler[] = [];

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn().mockImplementation(
    (eventName: string, handler: EventHandler) => {
      if (eventName === "watcher_status") _wsHandlers.push(handler);
      return Promise.resolve(() => {});
    },
  ),
}));

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue(""),
}));

// ---------------------------------------------------------------------------
// Imports — after mocks.
// ---------------------------------------------------------------------------
import { act } from "@testing-library/react";
import { LiveWatchFooter } from "../LiveWatchFooter";

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("LiveWatchFooter — AC15 (pip + label, no interval)", () => {
  it("renders exactly one pip element (data-testid=live-watch-pip)", () => {
    const { getAllByTestId } = render(<LiveWatchFooter />);
    const pips = getAllByTestId("live-watch-pip");
    expect(pips).toHaveLength(1);
  });

  it("renders the 'Live FS watch' label text", () => {
    const { getByText } = render(<LiveWatchFooter />);
    expect(getByText("Live FS watch")).toBeTruthy();
  });

  it("does NOT render any numeric interval value", () => {
    const { container } = render(<LiveWatchFooter />);
    const text = container.textContent ?? "";
    // No digit sequences that look like a polling interval (e.g. "5s", "5000")
    expect(text).not.toMatch(/\d+\s*(ms|sec|s)\b/i);
    // The only text rendered should be the label
    expect(text.trim()).toBe("Live FS watch");
  });

  it("does NOT render an element with testid 'polling-footer' (old component gone — AC15)", () => {
    const { queryByTestId } = render(<LiveWatchFooter />);
    expect(queryByTestId("polling-footer")).toBeNull();
  });

  it("pip has data-state='running' by default", () => {
    const { getByTestId } = render(<LiveWatchFooter />);
    const pip = getByTestId("live-watch-pip");
    expect(pip.getAttribute("data-state")).toBe("running");
  });

  it("pip has the running CSS class by default", () => {
    const { getByTestId } = render(<LiveWatchFooter />);
    const pip = getByTestId("live-watch-pip");
    expect(pip.className).toContain("live-watch-footer__pip--running");
  });
});

describe("LiveWatchFooter — AC16 (grey pip on errored)", () => {
  it("pip transitions to errored class when watcher_status errored fires", async () => {
    const { getByTestId } = render(<LiveWatchFooter />);

    await act(async () => {
      _wsHandlers.forEach((h) =>
        h({ payload: { state: "errored", error_kind: "kqueue_exhausted" } }),
      );
    });

    const pip = getByTestId("live-watch-pip");
    expect(pip.getAttribute("data-state")).toBe("errored");
    expect(pip.className).toContain("live-watch-footer__pip--errored");
    expect(pip.className).not.toContain("live-watch-footer__pip--running");
  });

  it("pip returns to running class when watcher_status running fires after errored", async () => {
    const { getByTestId } = render(<LiveWatchFooter />);

    await act(async () => {
      _wsHandlers.forEach((h) =>
        h({ payload: { state: "errored", error_kind: "init_failure" } }),
      );
    });

    await act(async () => {
      _wsHandlers.forEach((h) =>
        h({ payload: { state: "running" } }),
      );
    });

    const pip = getByTestId("live-watch-pip");
    expect(pip.getAttribute("data-state")).toBe("running");
    expect(pip.className).toContain("live-watch-footer__pip--running");
  });
});
