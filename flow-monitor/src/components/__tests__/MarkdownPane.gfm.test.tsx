/**
 * T34 — DOMPurify positive-fixture: GFM checkboxes, tables, and details preserved.
 *
 * Uses REAL markdown-it, REAL markdown-it-task-lists, and REAL DOMPurify (no mocks).
 * Verifies that the sanitiser's default profile (plus checkbox relaxation when
 * needed) does NOT strip legitimate GFM constructs.
 *
 * R-4 mitigation: if DOMPurify strips <input> by default, the narrowest
 * relaxation is applied — ADD_TAGS: ["input"], ADD_ATTR: ["type","disabled","checked"].
 */
import { describe, it, expect } from "vitest";
import { render, waitFor } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { readFileSync } from "fs";
import { join } from "path";
import MarkdownPane from "../MarkdownPane";

// Read the fixture once — no re-read per test (performance rule: no re-reading same file).
const FIXTURE_PATH = join(
  __dirname,
  "fixtures",
  "gfm.md"
);
const GFM_CONTENT = readFileSync(FIXTURE_PATH, "utf-8");

describe("MarkdownPane GFM positive fixture (real DOMPurify)", () => {
  it("(a) renders <input type='checkbox' disabled> for task-list items", async () => {
    render(<MarkdownPane content={GFM_CONTENT} />);

    await waitFor(() => {
      const pane = document.querySelector("[data-testid='markdown-pane']");
      expect(pane).not.toBeNull();
      // markdown-it-task-lists emits <input type="checkbox" disabled>
      const checkboxes = pane!.querySelectorAll(
        "input[type='checkbox'][disabled]"
      );
      expect(checkboxes.length).toBeGreaterThanOrEqual(2);
    });
  });

  it("(b) renders <table>, <thead>, <tbody> for GFM tables", async () => {
    render(<MarkdownPane content={GFM_CONTENT} />);

    await waitFor(() => {
      const pane = document.querySelector("[data-testid='markdown-pane']");
      expect(pane).not.toBeNull();
      expect(pane!.querySelector("table")).not.toBeNull();
      expect(pane!.querySelector("thead")).not.toBeNull();
      expect(pane!.querySelector("tbody")).not.toBeNull();
    });
  });

  it("(c) renders <details> and <summary> for collapsible blocks", async () => {
    render(<MarkdownPane content={GFM_CONTENT} />);

    await waitFor(() => {
      const pane = document.querySelector("[data-testid='markdown-pane']");
      expect(pane).not.toBeNull();
      expect(pane!.querySelector("details")).not.toBeNull();
      expect(pane!.querySelector("summary")).not.toBeNull();
    });
  });
});
