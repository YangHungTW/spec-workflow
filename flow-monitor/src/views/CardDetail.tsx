import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate, useSearchParams, Navigate } from "react-router-dom";
import { invoke } from "@tauri-apps/api/core";
import { CardDetailHeader } from "../components/CardDetailHeader";
import { StageChecklist } from "../components/StageChecklist";
import { TabStrip } from "../components/TabStrip";
import { NotesTimeline } from "../components/NotesTimeline";
import type { NoteEntry } from "../components/NotesTimeline";
import CardDetailMarkdownPane from "../components/CardDetailMarkdownPane";
import { DesignFolderIndex } from "../components/DesignFolderIndex";
import type { StageKey } from "../components/StagePill";
import type { IdleState } from "../components/IdleBadge";
import { useInvokeStore } from "../stores/invokeStore";

const SAFE_ID = /^[A-Za-z0-9_-]+$/;
function isSafeId(s: string | undefined): s is string {
  return typeof s === "string" && SAFE_ID.test(s);
}

// Static tab definitions without exists — existence is computed from IPC on mount.
const TAB_DEFINITIONS = [
  { id: "00-request", labelKey: "tab.request" as const, file: "00-request.md" },
  { id: "01-brainstorm", labelKey: "tab.brainstorm" as const, file: "01-brainstorm.md" },
  { id: "02-design", labelKey: "tab.design" as const, file: "02-design" },
  { id: "03-prd", labelKey: "tab.prd" as const, file: "03-prd.md" },
  { id: "04-tech", labelKey: "tab.tech" as const, file: "04-tech.md" },
  { id: "05-plan", labelKey: "tab.plan" as const, file: "05-plan.md" },
  { id: "06-tasks", labelKey: "tab.tasks" as const, file: "06-tasks.md" },
  { id: "07-gaps", labelKey: "tab.gaps" as const, file: "07-gaps.md" },
  { id: "08-verify", labelKey: "tab.verify" as const, file: "08-verify.md" },
];

interface ArtefactPresence {
  files_present: Record<string, boolean>;
}

interface SettingsResponse {
  repos?: string[];
}

interface CardDetailProps {
  /** When true, the view is read-only — path resolves under .specaffold/archive/ (D9). */
  isArchived?: boolean;
}

function CardDetail({ isArchived = false }: CardDetailProps) {
  const { repoId, slug } = useParams<{ repoId: string; slug: string }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const invokeStore = useInvokeStore();

  const [activeTabId, setActiveTabId] = useState<string>(TAB_DEFINITIONS[0].id);
  const [repoFullPath, setRepoFullPath] = useState<string | null>(null);
  const [tabContent, setTabContent] = useState<string>("");
  const [contentError, setContentError] = useState<string | null>(null);
  const tabContentRef = useRef<HTMLDivElement>(null);
  // filesPresent: null = not yet loaded (fall back to false for all tabs until resolved).
  const [filesPresent, setFilesPresent] = useState<Record<string, boolean> | null>(null);

  // Scroll to top when active tab or content changes.
  // The actual scroll container is the inner [data-testid="markdown-pane"]
  // (it has its own overflow-y:auto), not the parent tab-content div.
  useEffect(() => {
    if (tabContentRef.current) {
      tabContentRef.current.scrollTop = 0;
      const inner = tabContentRef.current.querySelector<HTMLElement>(
        '[data-testid="markdown-pane"]',
      );
      if (inner) inner.scrollTop = 0;
    }
  }, [activeTabId, tabContent]);

  const validRepoId = isSafeId(repoId) ? repoId : null;
  const validSlug = isSafeId(slug) ? slug : null;

  // Resolve full repo path from settings using the basename URL param
  useEffect(() => {
    if (!validRepoId) return;
    invoke<SettingsResponse>("get_settings")
      .then((s) => {
        const match = (s.repos ?? []).find(
          (p) => (p.split("/").pop() ?? p) === validRepoId,
        );
        setRepoFullPath(match ?? null);
      })
      .catch(() => setRepoFullPath(null));
  }, [validRepoId]);

  // Fetch which artefact files exist via list_feature_artefacts on mount and
  // whenever repo/slug/archived change. On IPC failure, fall back to all-false
  // so tabs degrade gracefully rather than silently showing stale data.
  useEffect(() => {
    if (!repoFullPath || !validSlug) return;
    invoke<ArtefactPresence>("list_feature_artefacts", {
      repo: repoFullPath,
      slug: validSlug,
      archived: isArchived,
    })
      .then((presence) => setFilesPresent(presence.files_present))
      .catch((e) => {
        console.warn("list_feature_artefacts failed; falling back to exists:false for all tabs", e);
        setFilesPresent({});
      });
  }, [repoFullPath, validSlug, isArchived]);

  // Load active-tab markdown content via read_artefact IPC
  useEffect(() => {
    if (!repoFullPath || !validSlug) return;
    if (activeTabId === "02-design") {
      setTabContent("");
      return;
    }
    const tab = TAB_DEFINITIONS.find((t) => t.id === activeTabId);
    if (!tab) return;
    setContentError(null);
    invoke<string>("read_artefact", {
      repo: repoFullPath,
      slug: validSlug,
      file: tab.file,
    })
      .then((content) => setTabContent(content))
      .catch((e) => {
        setTabContent("");
        setContentError(e instanceof Error ? e.message : String(e));
      });
  }, [activeTabId, repoFullPath, validSlug]);

  if (!validRepoId || !validSlug) {
    return <Navigate to="/" replace />;
  }

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

  // Compute the feature directory — archive path when isArchived, features path otherwise (D9).
  // ONE logic branch, one path string per D9 constraint.
  const featurePath = repoFullPath
    ? `${repoFullPath}/.specaffold/${isArchived ? "archive" : "features"}/${validSlug}`
    : `/${validRepoId}/.specaffold/${isArchived ? "archive" : "features"}/${validSlug}`;

  const stage: StageKey = "implement";
  const idleState: IdleState = "none";
  const notes: NoteEntry[] = [];

  return (
    <div className="card-detail" data-testid="card-detail">
      <CardDetailHeader
        repoId={validRepoId}
        slug={validSlug}
        stage={stage}
        idleState={idleState}
        featurePath={featurePath}
        onBack={handleBack}
        invokeStore={invokeStore}
        isArchived={isArchived}
      />

      <div className="card-detail__body">
        <aside className="card-detail__left-rail" data-testid="card-detail-left-rail">
          <StageChecklist currentStage={stage} />
          <NotesTimeline notes={notes} />
        </aside>

        <main className="card-detail__right-pane" data-testid="card-detail-right-pane">
          <TabStrip
            tabs={TAB_DEFINITIONS.map((tab) => ({
              ...tab,
              // Optimistic default while IPC is in-flight (null): show all tabs enabled
              // so interaction is not blocked before presence data arrives.
              // Once the IPC resolves, use the backend value; on error ({}) all are false.
              exists: filesPresent !== null ? (filesPresent[tab.file] ?? false) : true,
            }))}
            activeId={activeTabId}
            onSelect={setActiveTabId}
          />

          <div ref={tabContentRef} className="card-detail__tab-content" data-testid="tab-content-placeholder">
            {activeTabId === "02-design" ? (
              <DesignFolderIndex
                files={[
                  { name: "mockup.html", path: `${featurePath}/02-design/mockup.html` },
                  { name: "notes.md", path: `${featurePath}/02-design/notes.md` },
                  { name: "README.md", path: `${featurePath}/02-design/README.md` },
                ]}
                repoPath={repoFullPath ?? undefined}
                slug={validSlug}
              />
            ) : contentError ? (
              <p style={{ padding: 24, color: "var(--stalled-red)", fontSize: 12 }}>
                Failed to load: {contentError}
              </p>
            ) : (
              <CardDetailMarkdownPane content={tabContent} />
            )}
          </div>
        </main>
      </div>
    </div>
  );
}

export default CardDetail;
