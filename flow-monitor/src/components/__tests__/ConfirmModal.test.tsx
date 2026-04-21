/**
 * Tests for T104: ConfirmModal component (Seam F)
 *
 * AC8.a — Enter keypress is INERT: does NOT call onConfirm OR onCancel.
 * Cancel button has autoFocus — document.activeElement === cancelButton on mount.
 * Click Cancel → onCancel called.
 * Click Confirm → onConfirm called.
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { ConfirmModal } from "../ConfirmModal";

// Mock i18n — keys live in W5; stub here so tests are self-contained
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "modal.destroy.title": "Confirm destroy",
        "modal.destroy.cancel": "Cancel",
        "modal.destroy.confirm": "Confirm",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

const onCancel = vi.fn();
const onConfirm = vi.fn();

const BASE_PROPS = {
  command: "archive",
  slug: "test-session",
  onCancel,
  onConfirm,
};

describe("ConfirmModal", () => {
  beforeEach(() => {
    onCancel.mockReset();
    onConfirm.mockReset();
  });

  it("Cancel button has autoFocus — is document.activeElement on mount", () => {
    render(<ConfirmModal {...BASE_PROPS} />);
    const cancelButton = screen.getByRole("button", { name: /cancel/i });
    expect(document.activeElement).toBe(cancelButton);
  });

  it("Enter keypress does NOT call onConfirm (AC8.a — inert Enter)", () => {
    render(<ConfirmModal {...BASE_PROPS} />);
    fireEvent.keyDown(document, { key: "Enter", code: "Enter" });
    expect(onConfirm).not.toHaveBeenCalled();
  });

  it("Enter keypress does NOT call onCancel (AC8.a — inert Enter)", () => {
    render(<ConfirmModal {...BASE_PROPS} />);
    fireEvent.keyDown(document, { key: "Enter", code: "Enter" });
    expect(onCancel).not.toHaveBeenCalled();
  });

  it("Click Cancel calls onCancel", () => {
    render(<ConfirmModal {...BASE_PROPS} />);
    const cancelButton = screen.getByRole("button", { name: /cancel/i });
    fireEvent.click(cancelButton);
    expect(onCancel).toHaveBeenCalledOnce();
  });

  it("Click Confirm calls onConfirm", () => {
    render(<ConfirmModal {...BASE_PROPS} />);
    const confirmButton = screen.getByRole("button", { name: /confirm/i });
    fireEvent.click(confirmButton);
    expect(onConfirm).toHaveBeenCalledOnce();
  });

  it("renders the modal with command and slug visible", () => {
    render(<ConfirmModal {...BASE_PROPS} />);
    // The i18n stub interpolates {command} and {slug} in the title
    expect(screen.getByText(/archive/)).toBeTruthy();
    expect(screen.getByText(/test-session/)).toBeTruthy();
  });
});
