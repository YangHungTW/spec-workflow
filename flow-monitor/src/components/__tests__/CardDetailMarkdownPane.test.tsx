/**
 * Tests for T22: CardDetailMarkdownPane — MarkdownPane wrapper with AC9.k literal footer.
 *
 * AC9.k — footer reads EXACTLY "Read-only preview. Open in Finder to edit."
 *          (JSX literal, not i18n key — intentional carve-out per PRD §9 / AC9.k)
 * AC9.e — read-only: no contenteditable, no Edit button inside the pane
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import CardDetailMarkdownPane from "../CardDetailMarkdownPane";

// ---- Mock MarkdownPane (T16) — we only need structural confirmation ----
vi.mock("../MarkdownPane", () => ({
  default: ({ content }: { content: string }) => (
    <div data-testid="markdown-pane" data-content={content} />
  ),
}));

// ---- Mock i18n — should NOT be called for the footer (AC9.k carve-out) ----
const tSpy = vi.fn((key: string) => key);
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: tSpy,
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

describe("CardDetailMarkdownPane", () => {
  beforeEach(() => {
    tSpy.mockClear();
  });

  it("renders the wrapper container", () => {
    render(<CardDetailMarkdownPane content="# hello" />);
    expect(
      document.querySelector(".card-detail__markdown")
    ).not.toBeNull();
  });

  it("renders <MarkdownPane> with the supplied content", () => {
    render(<CardDetailMarkdownPane content="# test content" />);
    const pane = document.querySelector("[data-testid='markdown-pane']");
    expect(pane).not.toBeNull();
    expect(pane?.getAttribute("data-content")).toBe("# test content");
  });

  it("renders footer with EXACT literal text (AC9.k)", () => {
    render(<CardDetailMarkdownPane content="# hello" />);
    // AC9.k: string-match test — must be verbatim
    expect(
      screen.getByText(/^Read-only preview\. Open in Finder to edit\.$/)
    ).not.toBeNull();
  });

  it("footer text is NOT translated — t() not called for footer (AC9.k carve-out)", () => {
    render(<CardDetailMarkdownPane content="# hello" />);
    // The footer literal must appear in the DOM without going through i18n
    const footer = document.querySelector(".card-detail__markdown-footer");
    expect(footer).not.toBeNull();
    expect(footer?.textContent).toBe(
      "Read-only preview. Open in Finder to edit."
    );
    // t() should not have been called with anything resembling "footer"
    const footerCalls = tSpy.mock.calls.filter(([key]) =>
      String(key).toLowerCase().includes("footer")
    );
    expect(footerCalls).toHaveLength(0);
  });

  it("footer stays English even when locale is zh-TW (AC9.k carve-out from R11)", async () => {
    // Simulate zh-TW locale — i18n mock returns zh-TW-like strings for other keys
    const zhSpy = vi.fn((key: string) => {
      const map: Record<string, string> = {
        "btn.openInFinder": "在 Finder 中開啟",
        "btn.copyPath": "複製路徑",
      };
      return map[key] ?? key;
    });
    vi.doMock("../../i18n", () => ({
      useTranslation: () => ({
        t: zhSpy,
        locale: "zh-TW",
        setLocale: vi.fn(),
      }),
    }));

    // Re-render in zh-TW context — footer literal must still be English
    render(<CardDetailMarkdownPane content="## zh-TW test" />);
    await waitFor(() => {
      const footer = document.querySelector(".card-detail__markdown-footer");
      expect(footer?.textContent).toBe(
        "Read-only preview. Open in Finder to edit."
      );
    });
  });

  it("footer element has no contenteditable attribute (AC9.e — read-only)", () => {
    render(<CardDetailMarkdownPane content="# hello" />);
    const footer = document.querySelector(".card-detail__markdown-footer");
    expect(footer?.getAttribute("contenteditable")).toBeNull();
  });

  it("no button with role=button and name containing 'Edit' inside the pane (AC9.e)", () => {
    render(<CardDetailMarkdownPane content="# hello" />);
    const container = document.querySelector(".card-detail__markdown");
    const buttons = container?.querySelectorAll("button") ?? [];
    const editButtons = Array.from(buttons).filter((btn) =>
      /edit/i.test(btn.textContent ?? "")
    );
    expect(editButtons).toHaveLength(0);
  });

  it("wrapper container has no contenteditable (AC9.e — pane read-only)", () => {
    render(<CardDetailMarkdownPane content="# hello" />);
    const container = document.querySelector(".card-detail__markdown");
    expect(container?.getAttribute("contenteditable")).toBeNull();
  });
});
