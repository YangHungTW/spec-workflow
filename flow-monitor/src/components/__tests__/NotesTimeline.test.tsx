/**
 * Tests for T21: NotesTimeline component
 *
 * AC9.c — Notes rendered, source-order date prefixes preserved verbatim
 * AC9.i — newest-first order, NO truncation (B1 ceiling <100 entries assumed)
 *
 * Stub strategy: component accepts notes prop directly; no IPC mock needed.
 * Real data wiring (IPC read_artefact → parser) lands in a later integration task.
 */
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { NotesTimeline } from "../NotesTimeline";

const SAMPLE_7 = [
  { date: "2026-04-15", role: "PM", message: "initial brainstorm" },
  { date: "2026-04-16", role: "Architect", message: "design decision made" },
  { date: "2026-04-17", role: "Developer", message: "implementation started" },
  { date: "2026-04-17", role: "QA", message: "test cases drafted" },
  { date: "2026-04-18", role: "TPM", message: "wave plan updated" },
  { date: "2026-04-18", role: "Developer", message: "T18 complete" },
  { date: "2026-04-19", role: "Developer", message: "T21 in progress" },
];

describe("NotesTimeline", () => {
  it("renders all 7 notes (no truncation)", () => {
    render(<NotesTimeline notes={SAMPLE_7} />);
    const items = document.querySelectorAll("li");
    expect(items.length).toBe(7);
  });

  it("renders newest-first: first <li> carries the 2026-04-19 date (AC9.i)", () => {
    render(<NotesTimeline notes={SAMPLE_7} />);
    const items = document.querySelectorAll("li");
    const firstItem = items[0];
    // date is rendered verbatim via <time> element
    expect(firstItem.querySelector("time")?.textContent).toBe("2026-04-19");
  });

  it("renders oldest last: last <li> carries the 2026-04-15 date", () => {
    render(<NotesTimeline notes={SAMPLE_7} />);
    const items = document.querySelectorAll("li");
    const lastItem = items[items.length - 1];
    expect(lastItem.querySelector("time")?.textContent).toBe("2026-04-15");
  });

  it("renders 100 notes without truncation (AC9.i no-slice requirement)", () => {
    const notes100 = Array.from({ length: 100 }, (_, i) => ({
      date: `2026-01-${String(i + 1).padStart(2, "0")}`,
      role: "Developer",
      message: `entry ${i + 1}`,
    }));
    render(<NotesTimeline notes={notes100} />);
    const items = document.querySelectorAll("li");
    expect(items.length).toBe(100);
  });

  it("renders each entry with date, role, and message", () => {
    render(<NotesTimeline notes={SAMPLE_7} />);
    // newest entry
    const items = document.querySelectorAll("li");
    const newestItem = items[0];
    expect(newestItem.querySelector("time")?.textContent).toBe("2026-04-19");
    expect(newestItem.textContent).toContain("Developer");
    expect(newestItem.textContent).toContain("T21 in progress");
  });

  it("date prefix is preserved verbatim (AC9.c — no reformatting)", () => {
    const withIsoDate = [{ date: "2026-04-19", role: "PM", message: "verbatim check" }];
    render(<NotesTimeline notes={withIsoDate} />);
    const timeEl = document.querySelector("time");
    // Must be exactly as provided — no reformatting (e.g. no "Apr 19, 2026")
    expect(timeEl?.textContent).toBe("2026-04-19");
  });

  it("renders as <ol> (semantic ordered list — newest first implies ordering)", () => {
    render(<NotesTimeline notes={SAMPLE_7} />);
    expect(document.querySelector("ol")).toBeTruthy();
  });

  it("empty array renders nothing (no items, no error)", () => {
    const { container } = render(<NotesTimeline notes={[]} />);
    const items = container.querySelectorAll("li");
    expect(items.length).toBe(0);
  });

  it("component sorts correctly even when caller passes oldest-first order", () => {
    // Intentionally pass in ascending date order — component must still render newest first
    const ascendingOrder = [
      { date: "2026-01-01", role: "PM", message: "earliest" },
      { date: "2026-06-01", role: "Dev", message: "latest" },
    ];
    render(<NotesTimeline notes={ascendingOrder} />);
    const items = document.querySelectorAll("li");
    expect(items[0].querySelector("time")?.textContent).toBe("2026-06-01");
    expect(items[1].querySelector("time")?.textContent).toBe("2026-01-01");
  });
});
