import { render } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { TaskProgressBar } from "../TaskProgressBar";

describe("TaskProgressBar", () => {
  it("renders nothing when tasksTotal is 0", () => {
    const { container } = render(
      <TaskProgressBar tasksDone={0} tasksTotal={0} />,
    );
    expect(container.firstChild).toBeNull();
  });

  it("renders the progress bar when tasksTotal > 0", () => {
    const { container } = render(
      <TaskProgressBar tasksDone={3} tasksTotal={10} />,
    );
    expect(container.firstChild).not.toBeNull();
  });

  it("fills bar proportionally — 3/10 gives 30%", () => {
    const { container } = render(
      <TaskProgressBar tasksDone={3} tasksTotal={10} />,
    );
    const fill = container.querySelector(".task-progress-bar__fill") as HTMLElement;
    expect(fill).not.toBeNull();
    expect(fill.style.width).toBe("30%");
  });

  it("fills bar to 100% when done equals total", () => {
    const { container } = render(
      <TaskProgressBar tasksDone={5} tasksTotal={5} />,
    );
    const fill = container.querySelector(".task-progress-bar__fill") as HTMLElement;
    expect(fill.style.width).toBe("100%");
  });

  it("renders the literal label 'done / total'", () => {
    const { getByText } = render(
      <TaskProgressBar tasksDone={7} tasksTotal={20} />,
    );
    expect(getByText("7 / 20")).toBeTruthy();
  });

  it("renders without errors when total is large (no cap)", () => {
    expect(() =>
      render(<TaskProgressBar tasksDone={500} tasksTotal={1000} />),
    ).not.toThrow();
  });

  it("does not call any hooks (pure presentational — no throw)", () => {
    expect(() =>
      render(<TaskProgressBar tasksDone={1} tasksTotal={2} />),
    ).not.toThrow();
  });
});
