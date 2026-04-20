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

const SAFE_ID = /^[A-Za-z0-9_-]+$/;
function isSafeId(s: string | undefined): s is string {
  return typeof s === "string" && SAFE_ID.test(s);
}

const TAB_DEFINITIONS = [
  { id: "00-request", labelKey: "tab.request" as const, exists: true, file: "00-request.md" },
  { id: "01-brainstorm", labelKey: "tab.brainstorm" as const, exists: true, file: "01-brainstorm.md" },
  { id: "02-design", labelKey: "tab.design" as const, exists: true, file: "02-design" },
  { id: "03-prd", labelKey: "tab.prd" as const, exists: true, file: "03-prd.md" },
  { id: "04-tech", labelKey: "tab.tech" as const, exists: true, file: "04-tech.md" },
  { id: "05-plan", labelKey: "tab.plan" as const, exists: true, file: "05-plan.md" },
  { id: "06-tasks", labelKey: "tab.tasks" as const, exists: true, file: "06-tasks.md" },
  { id: "07-gaps", labelKey: "tab.gaps" as const, exists: true, file: "07-gaps.md" },
  { id: "08-verify", labelKey: "tab.verify" as const, exists: true, file: "08-verify.md" },
];

interface SettingsResponse {
  repos?: string[];
}

function CardDetail() {
  const { repoId, slug } = useParams<{ repoId: string; slug: string }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const [activeTabId, setActiveTabId] = useState<string>(TAB_DEFINITIONS[0].id);
  const [repoFullPath, setRepoFullPath] = useState<string | null>(null);
  const [tabContent, setTabContent] = useState<string>("");
  const [contentError, setContentError] = useState<string | null>(null);
  const tabContentRef = useRef<HTMLDivElement>(null);

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

  // Real absolute feature path from resolved repo (was hardcoded `/${repoId}/...`)
  const featurePath = repoFullPath
    ? `${repoFullPath}/.spec-workflow/features/${validSlug}`
    : `/${validRepoId}/.spec-workflow/features/${validSlug}`;

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
      />

      <div className="card-detail__body">
        <aside className="card-detail__left-rail" data-testid="card-detail-left-rail">
          <StageChecklist currentStage={stage} />
          <NotesTimeline notes={notes} />
        </aside>

        <main className="card-detail__right-pane" data-testid="card-detail-right-pane">
          <TabStrip
            tabs={TAB_DEFINITIONS}
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
