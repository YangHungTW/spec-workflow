/**
 * Tests for T102: SendPanel component — 3-tab strip per Screen 2.
 *
 * AC3.b — terminal-spawn tab is selected by default at mount.
 * Pipe tab — disabled with tooltip "Deferred to future release" (English fixed).
 * Clipboard tab — selectable; send calls dispatch with delivery: 'clipboard'.
 * Terminal tab — send calls dispatch with delivery: 'terminal'.
 * Pipe tab — send button is disabled (tab is not selectable).
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { SendPanel } from "../SendPanel";
import type { InvokeStore } from "../../stores/invokeStore";

// ---------------------------------------------------------------------------
// Minimal InvokeStore mock — only dispatch is exercised here.
// ---------------------------------------------------------------------------
function makeStore(): InvokeStore {
  return {
    inFlight: new Set<string>(),
    preflightCommand: null,
    preflightSlug: null,
    dispatch: vi.fn().mockResolvedValue(undefined),
  };
}

const BASE_PROPS = {
  command: "next-stage",
  slug: "my-feature",
  repo: "/Users/alice/projects/my-repo",
  entry: "card-detail" as const,
};

describe("SendPanel", () => {
  let store: InvokeStore;

  beforeEach(() => {
    store = makeStore();
  });

  // -------------------------------------------------------------------------
  // Pipe tab — disabled
  // -------------------------------------------------------------------------

  it("pipe tab has disabled attribute", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const pipeTab = screen.getByRole("tab", { name: /pipe/i });
    expect(pipeTab).toBeTruthy();
    expect(pipeTab.hasAttribute("disabled")).toBe(true);
  });

  it("pipe tab has tooltip 'Deferred to future release'", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const pipeTab = screen.getByRole("tab", { name: /pipe/i });
    expect(pipeTab.getAttribute("title")).toBe("Deferred to future release");
  });

  // -------------------------------------------------------------------------
  // Terminal-spawn tab — default selected (AC3.b)
  // -------------------------------------------------------------------------

  it("terminal-spawn tab has aria-selected='true' at mount (AC3.b)", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const terminalTab = screen.getByRole("tab", { name: /terminal/i });
    expect(terminalTab.getAttribute("aria-selected")).toBe("true");
  });

  it("pipe tab has aria-selected='false' at mount (pipe cannot be selected)", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const pipeTab = screen.getByRole("tab", { name: /pipe/i });
    expect(pipeTab.getAttribute("aria-selected")).toBe("false");
  });

  // -------------------------------------------------------------------------
  // Clipboard tab — selectable
  // -------------------------------------------------------------------------

  it("clicking clipboard tab gives it aria-selected='true'", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const clipboardTab = screen.getByRole("tab", { name: /clipboard/i });
    fireEvent.click(clipboardTab);
    expect(clipboardTab.getAttribute("aria-selected")).toBe("true");
  });

  it("after clicking clipboard, terminal tab loses aria-selected", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const clipboardTab = screen.getByRole("tab", { name: /clipboard/i });
    fireEvent.click(clipboardTab);
    const terminalTab = screen.getByRole("tab", { name: /terminal/i });
    expect(terminalTab.getAttribute("aria-selected")).toBe("false");
  });

  // -------------------------------------------------------------------------
  // Send button — dispatch with correct delivery
  // -------------------------------------------------------------------------

  it("Send on terminal-spawn tab calls dispatch with delivery: 'terminal'", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const sendBtn = screen.getByRole("button", { name: /send/i });
    fireEvent.click(sendBtn);
    expect(store.dispatch).toHaveBeenCalledTimes(1);
    expect(store.dispatch).toHaveBeenCalledWith(
      BASE_PROPS.command,
      BASE_PROPS.slug,
      BASE_PROPS.repo,
      BASE_PROPS.entry,
      "terminal",
    );
  });

  it("Send on clipboard tab calls dispatch with delivery: 'clipboard'", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const clipboardTab = screen.getByRole("tab", { name: /clipboard/i });
    fireEvent.click(clipboardTab);
    const sendBtn = screen.getByRole("button", { name: /send/i });
    fireEvent.click(sendBtn);
    expect(store.dispatch).toHaveBeenCalledTimes(1);
    expect(store.dispatch).toHaveBeenCalledWith(
      BASE_PROPS.command,
      BASE_PROPS.slug,
      BASE_PROPS.repo,
      BASE_PROPS.entry,
      "clipboard",
    );
  });

  // -------------------------------------------------------------------------
  // Pipe tab — clicking pipe tab does not select it; send button stays for
  // active (non-pipe) tab only. Pipe tab being disabled means the user cannot
  // select it — clicking does nothing.
  // -------------------------------------------------------------------------

  it("clicking pipe tab does not change active tab (disabled)", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const pipeTab = screen.getByRole("tab", { name: /pipe/i });
    // Attempt to click; because it is disabled the click should be no-op.
    fireEvent.click(pipeTab);
    // Terminal tab must still be selected.
    const terminalTab = screen.getByRole("tab", { name: /terminal/i });
    expect(terminalTab.getAttribute("aria-selected")).toBe("true");
  });

  // -------------------------------------------------------------------------
  // Textarea — present in body
  // -------------------------------------------------------------------------

  it("renders a textarea in the panel body", () => {
    render(<SendPanel {...BASE_PROPS} invokeStore={store} />);
    const textarea = document.querySelector("textarea");
    expect(textarea).toBeTruthy();
  });
});
