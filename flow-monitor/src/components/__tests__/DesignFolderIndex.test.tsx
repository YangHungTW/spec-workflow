/**
 * Tests for T20: DesignFolderIndex component
 *
 * AC9.h — 02-design tab shows sub-file list; clicking a row reveals the file
 *          in Finder via invoke("reveal_in_finder", { path }) (IPC stub).
 *
 * B2 boundary — exactly ONE action per row: "Reveal in Finder".
 * No "Open in browser", no "Edit", no "Preview" affordance.
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { DesignFolderIndex } from "../DesignFolderIndex";

// Stub Tauri IPC
const mockInvoke = vi.fn();
vi.mock("@tauri-apps/api/core", () => ({
  invoke: (...args: unknown[]) => mockInvoke(...args),
}));

// Stub i18n
vi.mock("../../i18n", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const map: Record<string, string> = {
        "btn.revealInFinder": "Reveal in Finder",
      };
      return map[key] ?? key;
    },
    locale: "en",
    setLocale: vi.fn(),
  }),
}));

const SAMPLE_FILES = [
  { name: "mockup.html", path: "/repo/.specaffold/features/my-feat/02-design/mockup.html" },
  { name: "notes.md", path: "/repo/.specaffold/features/my-feat/02-design/notes.md" },
  { name: "README.md", path: "/repo/.specaffold/features/my-feat/02-design/README.md" },
];

describe("DesignFolderIndex", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockInvoke.mockResolvedValue(undefined);
  });

  it("renders exactly 3 rows for 3 files", () => {
    render(<DesignFolderIndex files={SAMPLE_FILES} />);
    // Each row has a "Reveal in Finder" button
    const buttons = screen.getAllByRole("button", { name: /reveal in finder/i });
    expect(buttons).toHaveLength(3);
  });

  it("every button is exactly 'Reveal in Finder' — no other action (B2 boundary)", () => {
    render(<DesignFolderIndex files={SAMPLE_FILES} />);
    const allButtons = screen.queryAllByRole("button");
    const allReveal = allButtons.every((b) =>
      /reveal in finder/i.test(b.textContent ?? ""),
    );
    expect(allReveal).toBe(true);
  });

  it("displays file names in the list", () => {
    render(<DesignFolderIndex files={SAMPLE_FILES} />);
    expect(screen.getByText("mockup.html")).toBeTruthy();
    expect(screen.getByText("notes.md")).toBeTruthy();
    expect(screen.getByText("README.md")).toBeTruthy();
  });

  it("clicking 'Reveal in Finder' on notes.md calls invoke with reveal_in_finder and the correct path", () => {
    render(<DesignFolderIndex files={SAMPLE_FILES} />);
    const buttons = screen.getAllByRole("button", { name: /reveal in finder/i });
    // notes.md is the second row (index 1)
    fireEvent.click(buttons[1]);
    expect(mockInvoke).toHaveBeenCalledWith("reveal_in_finder", {
      path: "/repo/.specaffold/features/my-feat/02-design/notes.md",
    });
  });

  it("clicking 'Reveal in Finder' on mockup.html calls invoke with reveal_in_finder and the correct path", () => {
    render(<DesignFolderIndex files={SAMPLE_FILES} />);
    const buttons = screen.getAllByRole("button", { name: /reveal in finder/i });
    fireEvent.click(buttons[0]);
    expect(mockInvoke).toHaveBeenCalledWith("reveal_in_finder", {
      path: "/repo/.specaffold/features/my-feat/02-design/mockup.html",
    });
  });

  it("renders an empty list when no files are provided", () => {
    render(<DesignFolderIndex files={[]} />);
    const buttons = screen.queryAllByRole("button");
    expect(buttons).toHaveLength(0);
  });
});
