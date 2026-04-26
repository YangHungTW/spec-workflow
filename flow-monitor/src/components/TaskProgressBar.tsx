interface TaskProgressBarProps {
  tasksDone: number;
  tasksTotal: number;
}

/**
 * Horizontal progress bar showing done / total task counts.
 * Pure presentational — no hooks, no useEffect, no IPC calls.
 * Parent passes props from useTaskProgress (D7, R11).
 * Renders nothing when tasksTotal is 0.
 */
export function TaskProgressBar({ tasksDone, tasksTotal }: TaskProgressBarProps) {
  if (tasksTotal <= 0) return null;

  const pct = (tasksDone / tasksTotal) * 100;

  return (
    <div className="task-progress-bar">
      <div className="task-progress-bar__track">
        <div
          className="task-progress-bar__fill"
          style={{ width: `${pct}%` }}
        />
      </div>
      <span className="task-progress-bar__label">
        {tasksDone} / {tasksTotal}
      </span>
    </div>
  );
}
