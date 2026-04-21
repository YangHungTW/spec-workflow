/**
 * Tests for T100: ActionStrip component
 *
 * AC (from T100 scope):
 *   - Primary button text resolves via i18n key `action.advance_to.<next_stage>`
 *   - For fixture session at stage "prd", primary = "Advance to Tech"
 *   - Secondary button text = "Message / Choice"
 *   - Clicking primary calls onAdvance prop
 *   - Clicking secondary calls onMessage prop
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { ActionStrip } from "../ActionStrip";
import type { SessionState } from "../../stores/sessionStore";

// Mock i18n — keys needed for ActionStrip
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "action.advance_to.tech": "Advance to Tech",
        "action.message": "Message / Choice",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

const FIXTURE_SESSION: SessionState = {
  slug: "my-feature",
  stage: "prd",
  idleState: "stalled",
  lastUpdatedMs: Date.now() - 10 * 60 * 1000,
  noteExcerpt: "Some note",
  repoPath: "/Users/alice/projects/my-repo",
  repoId: "my-repo",
};

describe("ActionStrip", () => {
  it("renders primary button with 'Advance to Tech' for prd stage", () => {
    const onAdvance = vi.fn();
    const onMessage = vi.fn();
    render(
      <ActionStrip
        session={FIXTURE_SESSION}
        onAdvance={onAdvance}
        onMessage={onMessage}
      />,
    );
    expect(screen.getByText("Advance to Tech")).toBeTruthy();
  });

  it("renders secondary button with 'Message / Choice'", () => {
    const onAdvance = vi.fn();
    const onMessage = vi.fn();
    render(
      <ActionStrip
        session={FIXTURE_SESSION}
        onAdvance={onAdvance}
        onMessage={onMessage}
      />,
    );
    expect(screen.getByText("Message / Choice")).toBeTruthy();
  });

  it("clicking primary button calls onAdvance", () => {
    const onAdvance = vi.fn();
    const onMessage = vi.fn();
    render(
      <ActionStrip
        session={FIXTURE_SESSION}
        onAdvance={onAdvance}
        onMessage={onMessage}
      />,
    );
    const primaryBtn = screen.getByText("Advance to Tech");
    fireEvent.click(primaryBtn);
    expect(onAdvance).toHaveBeenCalledTimes(1);
    expect(onMessage).not.toHaveBeenCalled();
  });

  it("clicking secondary button calls onMessage", () => {
    const onAdvance = vi.fn();
    const onMessage = vi.fn();
    render(
      <ActionStrip
        session={FIXTURE_SESSION}
        onAdvance={onAdvance}
        onMessage={onMessage}
      />,
    );
    const secondaryBtn = screen.getByText("Message / Choice");
    fireEvent.click(secondaryBtn);
    expect(onMessage).toHaveBeenCalledTimes(1);
    expect(onAdvance).not.toHaveBeenCalled();
  });
});
