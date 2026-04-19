import { afterEach, describe, it, expect } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "../App";

afterEach(() => cleanup());

describe("App routing", () => {
  it("/ renders MainWindow placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("MainWindow")).toBeTruthy();
  });

  it("/repo/:repoId renders MainWindow placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/repo/abc"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("MainWindow")).toBeTruthy();
  });

  it("/feature/:repoId/:slug renders CardDetail placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/feature/abc/my-slug"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("CardDetail")).toBeTruthy();
  });

  it("/settings renders Settings placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/settings"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("Settings")).toBeTruthy();
  });

  it("/compact renders CompactPanel placeholder", () => {
    render(
      <MemoryRouter initialEntries={["/compact"]}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.getByText("CompactPanel")).toBeTruthy();
  });
});
