/**
 * parseTaskCounts — pure function unit tests (AC10, tech §6 risk 5).
 *
 * Covers:
 *   - 3-of-7 baseline case (AC10)
 *   - Case-insensitive [X] treated as done
 *   - Lines inside a code fence are excluded
 *   - Indented bullet lines are counted
 *   - Block-quoted lines (> prefix) are NOT counted (not a GFM task item)
 *   - Empty string returns zeros
 */

import { describe, it, expect } from "vitest";
import { parseTaskCounts } from "../artifactStore";

describe("parseTaskCounts", () => {
  it("counts 3 done and 4 total — AC10 baseline (3-of-7)", () => {
    const md = [
      "- [x] task one",
      "- [x] task two",
      "- [x] task three",
      "- [ ] task four",
      "- [ ] task five",
      "- [ ] task six",
      "- [ ] task seven",
    ].join("\n");
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 3, tasks_total: 7 });
  });

  it("counts uppercase [X] as done (case-insensitive)", () => {
    const md = ["- [X] upper done", "- [x] lower done", "- [ ] undone"].join("\n");
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 2, tasks_total: 3 });
  });

  it("excludes lines inside a code fence", () => {
    const md = [
      "- [x] before fence",
      "```",
      "- [x] inside fence — excluded",
      "- [ ] also inside — excluded",
      "```",
      "- [ ] after fence",
    ].join("\n");
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 1, tasks_total: 2 });
  });

  it("handles multiple code fences correctly", () => {
    const md = [
      "- [x] real task",
      "```",
      "- [x] in fence 1",
      "```",
      "- [ ] real undone",
      "```",
      "- [ ] in fence 2",
      "```",
    ].join("\n");
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 1, tasks_total: 2 });
  });

  it("counts indented bullet task lines", () => {
    const md = [
      "  - [x] indented done",
      "    - [ ] deeper indented undone",
      "- [ ] top-level undone",
    ].join("\n");
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 1, tasks_total: 3 });
  });

  it("does NOT count block-quoted lines (> prefix is not a GFM task list)", () => {
    const md = [
      "> - [x] block-quoted — not a task",
      "- [x] real task",
      "- [ ] real undone",
    ].join("\n");
    // Block-quoted line starts with '>' not whitespace+'-'; regex ^\s*-\s\[ does not match.
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 1, tasks_total: 2 });
  });

  it("returns zeros for empty string", () => {
    expect(parseTaskCounts("")).toEqual({ tasks_done: 0, tasks_total: 0 });
  });

  it("returns zeros when no task list items present", () => {
    const md = "# Heading\n\nSome prose with no checkboxes.\n";
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 0, tasks_total: 0 });
  });

  it("counts all done when every item is [x]", () => {
    const md = ["- [x] a", "- [x] b", "- [x] c"].join("\n");
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 3, tasks_total: 3 });
  });

  it("handles mixed-case fence token (opening fence with spaces before backticks)", () => {
    // The toggle fires on trimStart().startsWith("```"); indented ``` should also toggle
    const md = ["- [x] real", "  ```", "- [x] fenced", "  ```", "- [ ] real2"].join(
      "\n",
    );
    expect(parseTaskCounts(md)).toEqual({ tasks_done: 1, tasks_total: 2 });
  });
});
