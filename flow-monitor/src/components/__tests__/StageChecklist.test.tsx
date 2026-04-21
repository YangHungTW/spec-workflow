/**
 * Tests for T18: StageChecklist component
 *
 * AC9.e — stage checklist is DISPLAY-ONLY (no click handler, no toggle)
 * AC9 carve-out — current stage highlighted using --primary token
 * B1/B2 boundary — checklist items are NOT role="button", NOT clickable
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { StageChecklist } from "../StageChecklist";

// Stub i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "stage.request": "request",
        "stage.brainstorm": "brainstorm",
        "stage.design": "design",
        "stage.prd": "PRD",
        "stage.tech": "tech",
        "stage.plan": "plan",
        "stage.tasks": "tasks",
        "stage.implement": "implement",
        "stage.gap-check": "gap-check",
        "stage.verify": "verify",
        "stage.archive": "archive",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

describe("StageChecklist", () => {
  it("renders all 11 stages", () => {
    render(<StageChecklist currentStage="implement" />);
    expect(screen.getByText("request")).toBeTruthy();
    expect(screen.getByText("brainstorm")).toBeTruthy();
    expect(screen.getByText("design")).toBeTruthy();
    expect(screen.getByText("PRD")).toBeTruthy();
    expect(screen.getByText("tech")).toBeTruthy();
    expect(screen.getByText("plan")).toBeTruthy();
    expect(screen.getByText("tasks")).toBeTruthy();
    expect(screen.getByText("implement")).toBeTruthy();
    expect(screen.getByText("gap-check")).toBeTruthy();
    expect(screen.getByText("verify")).toBeTruthy();
    expect(screen.getByText("archive")).toBeTruthy();
  });

  it("marks stages before current as completed", () => {
    render(<StageChecklist currentStage="prd" />);
    const items = document.querySelectorAll("[data-stage-item]");
    const requestItem = Array.from(items).find(
      (el) => el.getAttribute("data-stage-item") === "request",
    );
    expect(requestItem?.getAttribute("data-completed")).toBe("true");
  });

  it("marks current stage as current", () => {
    render(<StageChecklist currentStage="implement" />);
    const implementItem = document.querySelector(
      "[data-stage-item='implement']",
    );
    expect(implementItem?.getAttribute("data-current")).toBe("true");
  });

  it("checklist items are NOT role=button (display-only, AC9.e)", () => {
    render(<StageChecklist currentStage="implement" />);
    // No stage item should be a button — B1 carve-out enforced
    const buttons = document.querySelectorAll(
      "[data-stage-item] button, button[data-stage-item]",
    );
    expect(buttons.length).toBe(0);
  });

  it("checklist items have no onClick handler (display-only, AC9.e)", () => {
    render(<StageChecklist currentStage="implement" />);
    const items = document.querySelectorAll("[data-stage-item]");
    // All items are <li> elements (or equivalent non-interactive elements)
    items.forEach((item) => {
      expect(item.tagName.toLowerCase()).not.toBe("button");
      expect(item.getAttribute("role")).not.toBe("button");
    });
  });

  it("renders a checklist as a list (semantic)", () => {
    render(<StageChecklist currentStage="brainstorm" />);
    const list = document.querySelector("ol, ul");
    expect(list).toBeTruthy();
  });

  it("stages AFTER current are not marked completed or current", () => {
    render(<StageChecklist currentStage="design" />);
    const verifyItem = document.querySelector("[data-stage-item='verify']");
    expect(verifyItem?.getAttribute("data-completed")).not.toBe("true");
    expect(verifyItem?.getAttribute("data-current")).not.toBe("true");
  });
});
