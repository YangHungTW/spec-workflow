/**
 * Tests for T24: EmptyState view
 *
 * AC12.a — empty state shows when zero repos registered
 * AC12.b — CTA functional (opens folder picker via IPC; on success navigates to /)
 * AC12.c — sidebar ghost item (explainer text visible)
 * R-5 mitigation — notification soft-prompt text present
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import EmptyState from "../../views/EmptyState";

// Mock i18n — returns key as value for deterministic assertions
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

// Mock Tauri IPC — handles both dialog_open_directory and add_repo commands
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

// Mock react-router-dom navigate
const mockNavigate = vi.fn();
vi.mock("react-router-dom", () => ({
  useNavigate: () => mockNavigate,
}));

import { invoke } from "@tauri-apps/api/core";

const mockInvoke = vi.mocked(invoke);

describe("EmptyState", () => {
  beforeEach(() => {
    mockInvoke.mockReset();
    mockNavigate.mockReset();
  });

  it("renders title via t('empty.title')", () => {
    render(<EmptyState />);
    expect(screen.getByText("empty.title")).toBeTruthy();
  });

  it("renders body via t('empty.body')", () => {
    render(<EmptyState />);
    expect(screen.getByText("empty.body")).toBeTruthy();
  });

  it("renders CTA button via t('empty.cta')", () => {
    render(<EmptyState />);
    expect(screen.getByRole("button", { name: "empty.cta" })).toBeTruthy();
  });

  it("does not render a card grid (no repos)", () => {
    const { container } = render(<EmptyState />);
    expect(container.querySelector("[data-testid='card-grid']")).toBeNull();
  });

  it("CTA click opens folder picker via dialog_open_directory IPC", async () => {
    // Simulate: dialog returns null (cancelled)
    mockInvoke.mockResolvedValueOnce(null);
    render(<EmptyState />);
    fireEvent.click(screen.getByRole("button", { name: "empty.cta" }));
    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("dialog_open_directory");
    });
  });

  it("CTA click: on successful path selection, invokes add_repo IPC", async () => {
    // First call: dialog returns a path; second call: add_repo
    mockInvoke
      .mockResolvedValueOnce("/Users/alice/my-project")
      .mockResolvedValueOnce(undefined);
    render(<EmptyState />);
    fireEvent.click(screen.getByRole("button", { name: "empty.cta" }));
    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("add_repo", {
        path: "/Users/alice/my-project",
      });
    });
  });

  it("CTA click: on successful add, navigates to /", async () => {
    mockInvoke
      .mockResolvedValueOnce("/Users/alice/my-project")
      .mockResolvedValueOnce(undefined);
    render(<EmptyState />);
    fireEvent.click(screen.getByRole("button", { name: "empty.cta" }));
    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith("/");
    });
  });

  it("CTA click: no navigation when user cancels folder picker (null)", async () => {
    mockInvoke.mockResolvedValueOnce(null);
    render(<EmptyState />);
    fireEvent.click(screen.getByRole("button", { name: "empty.cta" }));
    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("dialog_open_directory");
    });
    expect(mockNavigate).not.toHaveBeenCalled();
  });

  it("notification soft-prompt text is visible (R-5 mitigation)", () => {
    render(<EmptyState />);
    // The explainer mentions notifications — use data-testid for stable assertion
    expect(screen.getByTestId("notification-prompt")).toBeTruthy();
  });
});
