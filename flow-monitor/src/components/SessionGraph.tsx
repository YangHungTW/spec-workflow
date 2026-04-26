import { useEffect, useRef, useState } from "react";
import {
  useArtifactChanges,
  useTaskProgress,
  type ArtifactKind,
} from "../stores/artifactStore";
import type { StageKey } from "./StagePill";

// ---------------------------------------------------------------------------
// Layout constants — two-row DAG, 11 nodes.
// Row 1 (top): request → brainstorm → design → prd → tech → plan
// Row 2 (bottom): tasks → implement → gap-check → verify → archive
// Bridge: plan → tasks (end of row 1 to start of row 2).
// viewBox: 0 0 440 190
// ---------------------------------------------------------------------------

interface StageLayoutItem {
  stage: StageKey;
  x: number;
  y: number;
  row: 1 | 2;
}

const NODE_W = 60;
const NODE_H = 26;
const ROW1_Y = 30;
const ROW2_Y = 145;

const STAGE_LAYOUT: StageLayoutItem[] = [
  { stage: "request",    x: 35,  y: ROW1_Y, row: 1 },
  { stage: "brainstorm", x: 107, y: ROW1_Y, row: 1 },
  { stage: "design",     x: 179, y: ROW1_Y, row: 1 },
  { stage: "prd",        x: 251, y: ROW1_Y, row: 1 },
  { stage: "tech",       x: 323, y: ROW1_Y, row: 1 },
  { stage: "plan",       x: 395, y: ROW1_Y, row: 1 },
  { stage: "tasks",      x: 44,  y: ROW2_Y, row: 2 },
  { stage: "implement",  x: 132, y: ROW2_Y, row: 2 },
  { stage: "gap-check",  x: 220, y: ROW2_Y, row: 2 },
  { stage: "verify",     x: 308, y: ROW2_Y, row: 2 },
  { stage: "archive",    x: 396, y: ROW2_Y, row: 2 },
];

interface StageEdge {
  from: StageKey;
  to: StageKey;
  label?: string;
}

// Every edge carries an artifact label (PRD R2 / AC2). Convention: the label is
// the destination stage's primary artifact (the file or state the edge produces).
// Bridge edge (plan → tasks) connects the two rows.
const STAGE_EDGES: StageEdge[] = [
  { from: "request",    to: "brainstorm", label: "01-brainstorm.md" },
  { from: "brainstorm", to: "design",     label: "02-design/"       },
  { from: "design",     to: "prd",        label: "03-prd.md"        },
  { from: "prd",        to: "tech",       label: "04-tech.md"       },
  { from: "tech",       to: "plan",       label: "05-plan.md"       },
  { from: "plan",       to: "tasks",      label: "tasks.md"         },
  { from: "tasks",      to: "implement",  label: "[x] tasks"        },
  { from: "implement",  to: "gap-check",  label: "06-gap-check.md"  },
  { from: "gap-check",  to: "verify",     label: "07-verify.md"     },
  { from: "verify",     to: "archive",    label: "08-validate.md"   },
];

// ---------------------------------------------------------------------------
// Stage → ArtifactKind mapping for mtime lookup.
// ---------------------------------------------------------------------------

const STAGE_ARTIFACT: Partial<Record<StageKey, ArtifactKind>> = {
  request: "request",
  design:  "design",
  prd:     "prd",
  tech:    "tech",
  plan:    "plan",
  tasks:   "tasks",
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type NodeState = "completed" | "active" | "skipped" | "partial" | "future";

const STAGE_ORDER: StageKey[] = STAGE_LAYOUT.map((n) => n.stage);

function stageIndex(stage: StageKey): number {
  return STAGE_ORDER.indexOf(stage);
}

function nodeById(stage: StageKey): StageLayoutItem | undefined {
  return STAGE_LAYOUT.find((n) => n.stage === stage);
}

function formatWhisker(diffMs: number): string {
  const s = Math.floor(diffMs / 1000);
  return `${s}s ago`;
}

// ---------------------------------------------------------------------------
// SubComponent: BypassArc — dashed arc when brainstorm is skipped.
// ---------------------------------------------------------------------------

interface BypassArcProps {
  fromNode: StageLayoutItem;
  toNode: StageLayoutItem;
}

function BypassArc({ fromNode, toNode }: BypassArcProps) {
  const x1 = fromNode.x + NODE_W / 2;
  const x2 = toNode.x - NODE_W / 2;
  const arcY = fromNode.y - 24;
  return (
    <path
      data-bypass-arc="brainstorm"
      d={`M ${x1} ${fromNode.y - NODE_H / 2} Q ${(x1 + x2) / 2} ${arcY} ${x2} ${toNode.y - NODE_H / 2}`}
      stroke="var(--graph-bypass-stroke)"
      strokeDasharray="4 2"
      strokeWidth="1"
      fill="none"
    />
  );
}

// ---------------------------------------------------------------------------
// SubComponent: StageEdges
// ---------------------------------------------------------------------------

interface StageEdgesProps {
  currentStage: StageKey;
  brainstormSkipped: boolean;
}

function StageEdges({ currentStage, brainstormSkipped }: StageEdgesProps) {
  const currentIdx = stageIndex(currentStage);

  return (
    <>
      <defs>
        <marker id="sg-arrow" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
          <polygon points="0 0, 6 2, 0 4" fill="var(--graph-edge-future)" />
        </marker>
        <marker id="sg-arrow-done" markerWidth="6" markerHeight="4" refX="5" refY="2" orient="auto">
          <polygon points="0 0, 6 2, 0 4" fill="var(--graph-edge-done)" />
        </marker>
      </defs>

      {STAGE_EDGES.map((edge) => {
        if (brainstormSkipped && (edge.from === "brainstorm" || edge.to === "brainstorm")) {
          return null;
        }

        const fromNode = nodeById(edge.from);
        const toNode   = nodeById(edge.to);
        if (!fromNode || !toNode) return null;

        const fromIdx = stageIndex(edge.from);
        const toIdx   = stageIndex(edge.to);
        const isDone  = fromIdx < currentIdx && toIdx <= currentIdx;

        const x1 = fromNode.x + NODE_W / 2;
        const y1 = fromNode.y;
        const x2 = toNode.x - NODE_W / 2;
        const y2 = toNode.y;

        const stroke    = isDone ? "var(--graph-edge-done)" : "var(--graph-edge-future)";
        const strokeW   = isDone ? 1.5 : 1;
        const arrowId   = isDone ? "url(#sg-arrow-done)" : "url(#sg-arrow)";

        // Bridge edge (plan → tasks): curved path connecting the two rows.
        if (edge.from === "plan" && edge.to === "tasks") {
          const bx1 = fromNode.x + NODE_W / 2;
          const by1 = fromNode.y + NODE_H / 2;
          const bx2 = toNode.x - NODE_W / 2;
          const by2 = toNode.y;
          const cx  = (bx1 + bx2) / 2;
          const cy  = (by1 + by2) / 2 + 8;
          return (
            <g key={`${edge.from}-${edge.to}`}>
              <path
                data-stage-edge={`${edge.from}-${edge.to}`}
                d={`M ${bx1} ${by1} Q ${cx} ${cy} ${bx2} ${by2}`}
                stroke={stroke}
                strokeWidth={strokeW}
                fill="none"
                markerEnd={arrowId}
              />
              {edge.label && (
                <text
                  x={cx}
                  y={cy + 4}
                  fontSize="7"
                  fill="var(--graph-edge-label)"
                  textAnchor="middle"
                >
                  {edge.label}
                </text>
              )}
            </g>
          );
        }

        return (
          <g key={`${edge.from}-${edge.to}`}>
            <line
              data-stage-edge={`${edge.from}-${edge.to}`}
              x1={x1}
              y1={y1}
              x2={x2}
              y2={y2}
              stroke={stroke}
              strokeWidth={strokeW}
              markerEnd={arrowId}
            />
            {edge.label && (
              <text
                x={(x1 + x2) / 2}
                y={y1 - 6}
                fontSize="7"
                fill="var(--graph-edge-label)"
                textAnchor="middle"
              >
                {edge.label}
              </text>
            )}
          </g>
        );
      })}
    </>
  );
}

// ---------------------------------------------------------------------------
// SubComponent: StageNodes
// ---------------------------------------------------------------------------

interface StageNodesProps {
  currentStage: StageKey;
  brainstormSkipped: boolean;
  mtimes: Map<ArtifactKind, number>;
  tasksDone: number;
  tasksTotal: number;
  now: number;
}

function StageNodes({
  currentStage,
  brainstormSkipped,
  mtimes,
  tasksDone,
  tasksTotal,
  now,
}: StageNodesProps) {
  const currentIdx = stageIndex(currentStage);

  return (
    <>
      {STAGE_LAYOUT.map(({ stage, x, y, row }) => {
        const nodeIdx = stageIndex(stage);

        // Derive state
        let state: NodeState;
        if (brainstormSkipped && stage === "brainstorm") {
          state = "skipped";
        } else if (nodeIdx < currentIdx) {
          // tasks node: partial when implement is active and has task data
          if (stage === "tasks" && tasksTotal > 0) {
            state = "partial";
          } else {
            state = "completed";
          }
        } else if (nodeIdx === currentIdx) {
          state = "active";
        } else {
          state = "future";
        }

        const isActive = state === "active";
        const left     = x - NODE_W / 2;
        const top      = y - NODE_H / 2;

        // Whisker — show only when artifact mtime < 60s ago
        const artifactKind  = STAGE_ARTIFACT[stage];
        const mtime         = artifactKind !== undefined ? mtimes.get(artifactKind) : undefined;
        const diffMs        = mtime !== undefined ? now - mtime : undefined;
        const showWhisker   = diffMs !== undefined && diffMs >= 0 && diffMs < 60_000;

        return (
          <g
            key={stage}
            data-stage-node={stage}
            data-row={row}
            data-state={state}
            data-active={isActive ? "true" : undefined}
          >
            <title>{`${stage}: ${state}`}</title>

            <rect
              className={`session-graph__node-rect session-graph__node-rect--${state}`}
              x={left}
              y={top}
              width={NODE_W}
              height={NODE_H}
              rx="5"
              ry="5"
            />

            {state === "completed" && (
              <text
                x={left + NODE_W - 4}
                y={top + 5}
                fontSize="8"
                fill="var(--graph-check)"
                dominantBaseline="hanging"
                textAnchor="end"
              >
                ✓
              </text>
            )}

            {state === "partial" && tasksTotal > 0 ? (
              <>
                <text
                  className={`session-graph__node-label session-graph__node-label--${state}`}
                  x={x}
                  y={y - 4}
                  fontSize="8"
                  textAnchor="middle"
                  dominantBaseline="middle"
                >
                  {stage}
                </text>
                <text
                  x={x}
                  y={y + 7}
                  fontSize="7"
                  fill="var(--graph-partial-counter)"
                  textAnchor="middle"
                  dominantBaseline="middle"
                >
                  {tasksDone} / {tasksTotal}
                </text>
              </>
            ) : (
              <text
                className={`session-graph__node-label session-graph__node-label--${state}`}
                x={x}
                y={y}
                fontSize="8.5"
                textAnchor="middle"
                dominantBaseline="middle"
              >
                {stage}
              </text>
            )}

            {isActive && (
              <circle
                cx={left + NODE_W - 5}
                cy={top + 5}
                r="4"
                className="session-graph__spin-arc"
              />
            )}

            {showWhisker && (
              <text
                x={x}
                y={top + NODE_H + 10}
                fontSize="7"
                fill="var(--graph-whisker)"
                textAnchor="middle"
              >
                {formatWhisker(diffMs!)}
              </text>
            )}
          </g>
        );
      })}
    </>
  );
}

// ---------------------------------------------------------------------------
// SessionGraph — public export
// ---------------------------------------------------------------------------

export interface SessionGraphProps {
  repoPath: string;
  slug: string;
  currentStage: StageKey;
}

export function SessionGraph({ repoPath, slug, currentStage }: SessionGraphProps) {
  const mtimes = useArtifactChanges(repoPath, slug);
  const { tasks_done: tasksDone, tasks_total: tasksTotal } = useTaskProgress(repoPath, slug);
  const [now, setNow] = useState<number>(() => Date.now());
  const intervalRef   = useRef<ReturnType<typeof setInterval> | null>(null);

  // Refresh whisker relative timestamps every second; clear on unmount.
  useEffect(() => {
    intervalRef.current = setInterval(() => setNow(Date.now()), 1000);
    return () => {
      if (intervalRef.current !== null) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);

  const currentIdx      = stageIndex(currentStage);
  const brainstormIdx   = stageIndex("brainstorm");
  // brainstorm is skipped when we are past it and no design artifact exists
  const brainstormSkipped = currentIdx > brainstormIdx && !mtimes.has("design");

  const requestNode     = nodeById("request");
  const designNode      = nodeById("design");

  return (
    <div
      className="session-graph"
      role="img"
      aria-label={`Stage graph — current stage: ${currentStage}`}
    >
      <svg
        viewBox="0 0 440 190"
        className="session-graph__svg"
        aria-hidden="true"
        style={{ width: "100%", height: "100%", overflow: "visible" }}
      >
        <StageEdges
          currentStage={currentStage}
          brainstormSkipped={brainstormSkipped}
        />
        {brainstormSkipped && requestNode && designNode && (
          <BypassArc fromNode={requestNode} toNode={designNode} />
        )}
        <StageNodes
          currentStage={currentStage}
          brainstormSkipped={brainstormSkipped}
          mtimes={mtimes}
          tasksDone={tasksDone}
          tasksTotal={tasksTotal}
          now={now}
        />
      </svg>
    </div>
  );
}

export default SessionGraph;
