import "@testing-library/jest-dom";

// jsdom doesn't implement scrollIntoView; stub it globally so components using
// TabStrip (or anything calling scrollIntoView on a ref) render in tests.
if (typeof window !== "undefined" && window.HTMLElement) {
  window.HTMLElement.prototype.scrollIntoView = function () {
    // no-op
  };
}
