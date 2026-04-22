import { render } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { AgentPill } from "../AgentPill";

// Stub i18n — returns key so we can assert label text
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

describe("AgentPill", () => {
  describe("data-color attribute matches ROLE_TO_COLOR", () => {
    it("developer → green", () => {
      const { container } = render(<AgentPill role="developer" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill).not.toBeNull();
      expect(pill.getAttribute("data-color")).toBe("green");
    });

    it("pm → purple", () => {
      const { container } = render(<AgentPill role="pm" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill.getAttribute("data-color")).toBe("purple");
    });

    it("architect → cyan", () => {
      const { container } = render(<AgentPill role="architect" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill.getAttribute("data-color")).toBe("cyan");
    });

    it("tpm → yellow", () => {
      const { container } = render(<AgentPill role="tpm" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill.getAttribute("data-color")).toBe("yellow");
    });

    it("designer → pink", () => {
      const { container } = render(<AgentPill role="designer" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill.getAttribute("data-color")).toBe("pink");
    });

    it("qa-analyst → orange", () => {
      const { container } = render(<AgentPill role="qa-analyst" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill.getAttribute("data-color")).toBe("orange");
    });

    it("qa-tester → blue", () => {
      const { container } = render(<AgentPill role="qa-tester" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill.getAttribute("data-color")).toBe("blue");
    });
  });

  describe("data-role attribute", () => {
    it("sets data-role to the role string", () => {
      const { container } = render(<AgentPill role="developer" />);
      const pill = container.querySelector(".agent-pill") as HTMLElement;
      expect(pill.getAttribute("data-role")).toBe("developer");
    });
  });

  describe("dot element", () => {
    it("renders .agent-pill__dot for non-reviewer roles", () => {
      const { container } = render(<AgentPill role="developer" />);
      expect(container.querySelector(".agent-pill__dot")).not.toBeNull();
    });

    it("renders .agent-pill__dot for reviewer roles", () => {
      const { container } = render(<AgentPill role="reviewer-security" />);
      expect(container.querySelector(".agent-pill__dot")).not.toBeNull();
    });
  });

  describe("i18n label", () => {
    it("renders t('role.developer') as label text", () => {
      const { getByText } = render(<AgentPill role="developer" />);
      expect(getByText("role.developer")).toBeTruthy();
    });

    it("renders t('role.pm') as label text", () => {
      const { getByText } = render(<AgentPill role="pm" />);
      expect(getByText("role.pm")).toBeTruthy();
    });
  });

  describe("axis sub-badge — reviewer roles", () => {
    it("reviewer-security renders axis badge with text 'sec'", () => {
      const { container } = render(<AgentPill role="reviewer-security" />);
      const badge = container.querySelector(".agent-pill__axis") as HTMLElement;
      expect(badge).not.toBeNull();
      expect(badge.textContent).toBe("sec");
    });

    it("reviewer-performance renders axis badge with text 'perf'", () => {
      const { container } = render(<AgentPill role="reviewer-performance" />);
      const badge = container.querySelector(".agent-pill__axis") as HTMLElement;
      expect(badge).not.toBeNull();
      expect(badge.textContent).toBe("perf");
    });

    it("reviewer-style renders axis badge with text 'style'", () => {
      const { container } = render(<AgentPill role="reviewer-style" />);
      const badge = container.querySelector(".agent-pill__axis") as HTMLElement;
      expect(badge).not.toBeNull();
      expect(badge.textContent).toBe("style");
    });
  });

  describe("axis sub-badge — non-reviewer roles", () => {
    const nonReviewerRoles = [
      "pm",
      "architect",
      "tpm",
      "developer",
      "designer",
      "qa-analyst",
      "qa-tester",
    ] as const;

    for (const role of nonReviewerRoles) {
      it(`${role} has no axis sub-badge`, () => {
        const { container } = render(<AgentPill role={role} />);
        expect(container.querySelector(".agent-pill__axis")).toBeNull();
      });
    }
  });
});
