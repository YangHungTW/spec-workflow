import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";

// These imports will fail (red) until the stub files exist.
import MainWindow from "../MainWindow";
import CardDetail from "../CardDetail";
import Settings from "../Settings";
import EmptyState from "../EmptyState";
import CompactPanel from "../CompactPanel";

describe("Route stub placeholders", () => {
  it("MainWindow renders placeholder text", () => {
    render(<MainWindow />);
    expect(screen.getByText("MainWindow")).toBeTruthy();
  });

  it("CardDetail renders placeholder text", () => {
    render(<CardDetail />);
    expect(screen.getByText("CardDetail")).toBeTruthy();
  });

  it("Settings renders placeholder text", () => {
    render(<Settings />);
    expect(screen.getByText("Settings")).toBeTruthy();
  });

  it("EmptyState renders placeholder text", () => {
    render(<EmptyState />);
    expect(screen.getByText("EmptyState")).toBeTruthy();
  });

  it("CompactPanel renders placeholder text", () => {
    render(<CompactPanel />);
    expect(screen.getByText("CompactPanel")).toBeTruthy();
  });
});
