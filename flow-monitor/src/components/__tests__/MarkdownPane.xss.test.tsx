/**
 * Seam 7 — DOMPurify XSS fixture test.
 *
 * This test intentionally does NOT mock DOMPurify or markdown-it.
 * It verifies that the real DOMPurify library (loaded in jsdom) strips all
 * three classic XSS attack vectors before they can reach the DOM.
 *
 * MarkdownPane.basic.test.tsx mocks DOMPurify to isolate render logic; this
 * file is the security-contract test and must exercise the real sanitiser.
 */
import { describe, it, expect } from "vitest";
import { render, waitFor } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import DOMPurify from "dompurify";
import { readFileSync } from "fs";
import { join } from "path";
import MarkdownPane from "../MarkdownPane";

// Load the XSS fixture from the fixtures directory next to this test file.
const xssFixture = readFileSync(
  join(__dirname, "fixtures", "xss.md"),
  "utf-8"
);

// Raw HTML strings that embed all three attack vectors directly.
// These are fed to DOMPurify independently of MarkdownPane so that the
// sanitiser is exercised on the exact threat payloads (markdown-it's
// html:false option escapes raw HTML, so the MarkdownPane render path
// provides defence-in-depth while DOMPurify is the final safety net).
const scriptVector = '<script>alert("xss")</script>';
const onclickVector = '<a href="https://example.com" onclick="alert(1)">click me</a>';
const javascriptVector = '<a href="javascript:alert(1)">click me</a>';

describe("MarkdownPane XSS — real DOMPurify default profile strips attack vectors", () => {
  it("(a) DOMPurify strips <script> element", () => {
    const dirty = `<p>safe text</p>${scriptVector}`;
    const clean = DOMPurify.sanitize(dirty);
    // Parse the sanitised HTML into a temporary container to allow DOM queries.
    const container = document.createElement("div");
    container.innerHTML = clean;
    expect(container.querySelector("script")).toBeNull();
  });

  it("(b) DOMPurify strips onclick attribute", () => {
    const clean = DOMPurify.sanitize(onclickVector);
    const container = document.createElement("div");
    container.innerHTML = clean;
    const anchor = container.querySelector("a");
    // The anchor itself may survive (href is safe); onclick must not.
    expect(anchor?.getAttribute("onclick")).toBeNull();
    expect(clean).not.toContain("onclick");
  });

  it("(c) DOMPurify strips javascript: URL from href", () => {
    const clean = DOMPurify.sanitize(javascriptVector);
    const container = document.createElement("div");
    container.innerHTML = clean;
    const anchor = container.querySelector("a");
    const href = anchor?.getAttribute("href") ?? "";
    expect(href).not.toMatch(/^javascript:/i);
    expect(clean).not.toContain("javascript:");
  });

  it("MarkdownPane renders xss fixture without <script> element in DOM", async () => {
    const { container } = render(<MarkdownPane content={xssFixture} />);

    await waitFor(() => {
      const pane = container.querySelector("[data-testid='markdown-pane']");
      expect(pane).not.toBeNull();
      // After markdown-it (html:false) + DOMPurify, no script element must exist.
      expect(pane!.querySelector("script")).toBeNull();
    });
  });

  it("MarkdownPane renders xss fixture without onclick attribute in DOM", async () => {
    const { container } = render(<MarkdownPane content={xssFixture} />);

    await waitFor(() => {
      const pane = container.querySelector("[data-testid='markdown-pane']");
      expect(pane).not.toBeNull();
      // No element anywhere in the rendered pane may carry an onclick handler.
      const withOnclick = pane!.querySelectorAll("[onclick]");
      expect(withOnclick.length).toBe(0);
    });
  });

  it("MarkdownPane renders xss fixture without javascript: href in DOM", async () => {
    const { container } = render(<MarkdownPane content={xssFixture} />);

    await waitFor(() => {
      const pane = container.querySelector("[data-testid='markdown-pane']");
      expect(pane).not.toBeNull();
      const anchors = Array.from(pane!.querySelectorAll("a[href]"));
      const jsAnchors = anchors.filter((a) =>
        (a.getAttribute("href") ?? "").toLowerCase().startsWith("javascript:")
      );
      expect(jsAnchors.length).toBe(0);
    });
  });
});
