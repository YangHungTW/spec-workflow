import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, waitFor } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import MarkdownPane from "../MarkdownPane";

// markdown-it is dynamically imported (lazy) inside the component.
// We provide a constructor-compatible mock so `new MarkdownIt(...)` works.
vi.mock("markdown-it", () => {
  // Must be a real function so it can be called with `new`.
  function MockMarkdownIt() {
    this.use = function () {
      return this;
    };
    this.render = function (md: string): string {
      // Minimal markdown → HTML mapping sufficient for acceptance checks.
      let html = md;
      html = html.replace(/^# (.+)$/m, "<h1>$1</h1>");
      html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
      return html;
    };
  }
  return { default: MockMarkdownIt };
});

const sanitizeSpy = vi.fn((html: string) => html);

vi.mock("dompurify", () => {
  return {
    // DOMPurify.sanitize passes content through in tests; the real sanitiser
    // runs in the browser. Returning the input unchanged lets us assert on the
    // markdown render output without DOMPurify stripping valid HTML in jsdom.
    default: { sanitize: sanitizeSpy },
  };
});

vi.mock("markdown-it-task-lists", () => ({
  // Plugin function — called as md.use(taskLists); just a no-op in tests.
  default: vi.fn(),
}));

describe("MarkdownPane", () => {
  beforeEach(() => {
    sanitizeSpy.mockClear();
  });

  it("renders heading and bold from markdown input", async () => {
    render(<MarkdownPane content={"# hello\n\n**bold**"} />);

    await waitFor(() => {
      const container = document.querySelector("[data-testid='markdown-pane']");
      expect(container).not.toBeNull();
      expect(container!.innerHTML).toContain("<h1>hello</h1>");
      expect(container!.innerHTML).toContain("<strong>bold</strong>");
    });
  });

  it("renders empty string without crashing", async () => {
    render(<MarkdownPane content="" />);
    await waitFor(() => {
      expect(
        document.querySelector("[data-testid='markdown-pane']")
      ).not.toBeNull();
    });
  });

  it("renders a loading placeholder before the lazy import resolves", () => {
    // On first synchronous render, before useEffect fires, the pane must
    // already be in the DOM (even with empty content) — no crash during
    // the initial paint.
    render(<MarkdownPane content="# hello" />);
    expect(
      document.querySelector("[data-testid='markdown-pane']")
    ).not.toBeNull();
  });

  it("DOMPurify.sanitize is called as the final step before insertion", async () => {
    render(<MarkdownPane content={"# hello\n\n**bold**"} />);

    await waitFor(() => {
      expect(sanitizeSpy).toHaveBeenCalled();
    });

    // The argument passed to sanitize must contain the markdown-rendered HTML,
    // confirming sanitise runs on the rendered output (not on raw markdown).
    const calls = sanitizeSpy.mock.calls;
    const lastArg: string = calls[calls.length - 1][0];
    expect(lastArg).toContain("<h1>hello</h1>");
  });
});
