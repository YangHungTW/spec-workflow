import { render } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { IdleBadge } from "../IdleBadge";

// Stub i18n — same pattern as IdleBadge.test.tsx (T14 not yet merged)
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

/**
 * AC9.j — stalled IdleBadge is static: no CSS animation, transition, or @keyframes.
 *
 * JSDOM limitation: JSDOM's getComputedStyle does not fully simulate a real
 * browser's cascade. CSS @keyframes and animation shorthand declared in external
 * stylesheets are NOT reflected by getComputedStyle in JSDOM. The assertions
 * below cover two complementary layers:
 *
 *   1. getComputedStyle on the element — catches inline-style animations and
 *      any CSS that JSDOM happens to compute (typically returns "" or "none"
 *      for animation properties when no stylesheet is injected at test time).
 *
 *   2. <style> tag scan in document — catches any @keyframes or animation:
 *      declarations that a global stylesheet may have injected into the
 *      test document, targeting the badge's class (.idle-badge) or its
 *      data-idle-state attribute.
 *
 * If the component ever gains a real CSS animation, it should be caught by at
 * least one of these layers. For authoritative visual confirmation that no
 * animation runs in the browser, add a manual smoke-test step to the T42 README.
 */

describe("IdleBadge – AC9.j: no animation or transition (computed-style harness)", () => {
  it("getComputedStyle: animation-name is 'none' or empty for stalled state", () => {
    const { container } = render(<IdleBadge state="stalled" />);
    const badge = container.firstChild as HTMLElement;

    const computed = window.getComputedStyle(badge);
    const animationName = computed.getPropertyValue("animation-name");

    // JSDOM returns "" or "none" when no animation is applied; both are acceptable.
    expect(["", "none"]).toContain(animationName);
  });

  it("getComputedStyle: animation-duration is '0s' or empty for stalled state", () => {
    const { container } = render(<IdleBadge state="stalled" />);
    const badge = container.firstChild as HTMLElement;

    const computed = window.getComputedStyle(badge);
    const animationDuration = computed.getPropertyValue("animation-duration");

    // JSDOM returns "", "0s", or "auto" when no animation is set.
    // "auto" is JSDOM's default for animation-duration when no animation is active.
    expect(["", "0s", "auto"]).toContain(animationDuration);
  });

  it("getComputedStyle: transition-property does not drive repeating visual change for stalled state", () => {
    const { container } = render(<IdleBadge state="stalled" />);
    const badge = container.firstChild as HTMLElement;

    const computed = window.getComputedStyle(badge);
    const transitionProperty = computed.getPropertyValue("transition-property");

    // Acceptable values: JSDOM returns "" or "all" (default) with duration 0,
    // or "none". Repeating-driving properties like "opacity" or "background-color"
    // paired with a positive duration would be a violation of AC9.j.
    const transitionDuration = computed.getPropertyValue("transition-duration");

    if (
      transitionProperty !== "" &&
      transitionProperty !== "none"
    ) {
      // If a transition-property is set, the duration must be 0s (no-op).
      expect(["", "0s"]).toContain(transitionDuration);
    }
  });

  it("no @keyframes rule in document <style> tags targets .idle-badge or [data-idle-state]", () => {
    render(<IdleBadge state="stalled" />);

    // Walk all <style> elements injected into the test document and confirm
    // none contains a @keyframes block followed by a rule that references
    // the badge's selector (.idle-badge or data-idle-state).
    const styleEls = Array.from(document.querySelectorAll("style"));
    const badgeKeyframesFound = styleEls.some((el) => {
      const text = el.textContent ?? "";
      // A keyframes rule linked to the badge would mention its class or attribute
      // inside a @keyframes block or animation shorthand.
      return (
        /@keyframes/.test(text) &&
        (/\.idle-badge/.test(text) || /idle-state/.test(text))
      );
    });

    expect(badgeKeyframesFound).toBe(false);
  });

  it("no animation: declaration in document <style> tags targets .idle-badge or [data-idle-state]", () => {
    render(<IdleBadge state="stalled" />);

    const styleEls = Array.from(document.querySelectorAll("style"));
    const animationRuleFound = styleEls.some((el) => {
      const text = el.textContent ?? "";
      // Look for animation property declarations inside a rule block that
      // targets the badge. This is a heuristic; a false-positive is safe
      // (it blocks the build) but a false-negative would miss an out-of-file
      // stylesheet, which is why the manual smoke step in T42 is also required.
      return (
        /animation\s*:/.test(text) &&
        (/\.idle-badge/.test(text) || /idle-state/.test(text))
      );
    });

    expect(animationRuleFound).toBe(false);
  });
});
