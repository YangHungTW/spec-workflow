import { useParams, useNavigate, useSearchParams } from "react-router-dom";
import { CardDetailHeader } from "../components/CardDetailHeader";
import { StageChecklist } from "../components/StageChecklist";
import type { StageKey } from "../components/StagePill";
import type { IdleState } from "../components/IdleBadge";

/**
 * The 9 markdown document tabs shown in CardDetail.
 * T19 will add horizontal scroll + active-tab auto-scroll-into-view.
 * T22 will wrap content with MarkdownPane + read-only footer.
 * T18 provides only the skeleton: container + 9 tab button stubs.
 */
const TAB_DEFINITIONS = [
  { id: "00-request", label: "00 request" },
  { id: "01-brainstorm", label: "01 brainstorm" },
  { id: "02-design", label: "02 design" },
  { id: "03-prd", label: "03 prd" },
  { id: "04-tech", label: "04 tech" },
  { id: "05-plan", label: "05 plan" },
  { id: "06-tasks", label: "06 tasks" },
  { id: "07-gaps", label: "07 gaps" },
  { id: "08-verify", label: "08 verify" },
] as const;

/**
 * CardDetail — master-detail view for a single specflow feature session.
 *
 * Layout (AC9.a — master-detail, same-window nav, not a modal or drawer):
 *   - CardDetailHeader: breadcrumb back + repo/slug title + stage pill +
 *     idle badge + 2 action buttons
 *   - Left rail: StageChecklist (display-only) + Notes placeholder (T21)
 *   - Right pane: tab-strip placeholder (9 stubs, T19 adds scroll) +
 *     content area (T19/T22 wire content)
 *
 * Breadcrumb back (AC9.f): restores MainWindow filter/sort/repo by reading
 * the ?sort=<axis>&repo=<id> search params stored in the URL before navigation.
 * The MainWindow stores these in the URL so they survive a full React remount.
 *
 * B2 boundary: NO edit affordance, NO save button, NO command-trigger (AC9.e).
 */
function CardDetail() {
  const { repoId = "unknown", slug = "unknown" } = useParams<{
    repoId: string;
    slug: string;
  }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  /**
   * Reconstruct the MainWindow URL with restored filter state from search params.
   * MainWindow saves sort= and repo= before navigating into detail (AC9.f).
   */
  function buildBackUrl(): string {
    const sort = searchParams.get("sort");
    const repo = searchParams.get("repo");
    const params = new URLSearchParams();
    if (sort) params.set("sort", sort);
    if (repo) params.set("repo", repo);
    const qs = params.toString();
    return qs ? `/?${qs}` : "/";
  }

  function handleBack() {
    navigate(buildBackUrl());
  }

  /**
   * Feature directory path — derived from repoId and slug.
   * In production this would come from IPC list_sessions or read_artefact.
   * T18 skeleton uses a synthesised path; real path wiring lands in T19/T20.
   */
  const featurePath = `/${repoId}/.spec-workflow/features/${slug}`;

  /**
   * Stage and idleState — in production loaded via IPC get_session or
   * derived from the sessions list in sessionStore. T18 skeleton defaults
   * so the header and checklist render; T17/T19 wire real data.
   */
  const stage: StageKey = "implement";
  const idleState: IdleState = "none";

  return (
    <div className="card-detail" data-testid="card-detail">
      <CardDetailHeader
        repoId={repoId}
        slug={slug}
        stage={stage}
        idleState={idleState}
        featurePath={featurePath}
        onBack={handleBack}
      />

      <div className="card-detail__body">
        {/* Left rail: stage checklist + notes timeline placeholder (T21) */}
        <aside
          className="card-detail__left-rail"
          data-testid="card-detail-left-rail"
        >
          <StageChecklist currentStage={stage} />

          {/* Notes timeline — rendered by T21 (NotesTimeline component) */}
          <div
            className="card-detail__notes-placeholder"
            data-testid="notes-timeline-placeholder"
          />
        </aside>

        {/* Right pane: tab strip + content area */}
        <main
          className="card-detail__right-pane"
          data-testid="card-detail-right-pane"
        >
          {/*
           * Tab strip — T18 provides 9 stub buttons only.
           * T19 adds horizontal scroll + active-tab auto-scroll-into-view.
           * NO overflow menu, NO wrap (T19 constraint).
           */}
          <div
            className="card-detail__tab-strip"
            data-testid="tab-strip-placeholder"
            role="tablist"
          >
            {TAB_DEFINITIONS.map((tab) => (
              <button
                key={tab.id}
                type="button"
                role="tab"
                className="card-detail__tab"
                data-tab-id={tab.id}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Tab content area — T19/T20/T22 wire real content */}
          <div
            className="card-detail__tab-content"
            data-testid="tab-content-placeholder"
          />
        </main>
      </div>
    </div>
  );
}

export default CardDetail;
