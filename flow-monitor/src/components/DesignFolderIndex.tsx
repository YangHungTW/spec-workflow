import { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { useTranslation } from "../i18n";
import CardDetailMarkdownPane from "./CardDetailMarkdownPane";

export interface DesignFile {
  name: string;
  path: string;
}

interface DesignFolderIndexProps {
  files: DesignFile[];
  /** Repo path + slug needed for read_artefact IPC (preview .md sub-files) */
  repoPath?: string;
  slug?: string;
}

/**
 * DesignFolderIndex — file index for the 02-design tab.
 *
 * AC9.h carve-out clarification (post-runtime feedback):
 *   - .md sub-files (notes.md, README.md): inline preview via read_artefact + MarkdownPane
 *   - .html / other: Reveal in Finder only (no in-app rendering — XSS risk per T20 design)
 *
 * B2 boundary: NO edit, NO delete. Preview is read-only.
 */
export function DesignFolderIndex({ files, repoPath, slug }: DesignFolderIndexProps) {
  const { t } = useTranslation();
  const [previewing, setPreviewing] = useState<DesignFile | null>(null);
  const [previewContent, setPreviewContent] = useState<string>("");
  const [error, setError] = useState<string | null>(null);

  function handleReveal(path: string) {
    void invoke("reveal_in_finder", { path });
  }

  function handleOpen(path: string) {
    // open_in_finder uses macOS `open <path>` which routes by file type:
    // .html → default browser, folder → Finder, etc.
    void invoke("open_in_finder", { path });
  }

  function handlePreview(file: DesignFile) {
    if (!repoPath || !slug) {
      setError("Cannot preview: missing repo context");
      return;
    }
    setError(null);
    setPreviewing(file);
    setPreviewContent("");
    invoke<string>("read_artefact", {
      repo: repoPath,
      slug,
      file: `02-design/${file.name}`,
    })
      .then((content) => setPreviewContent(content))
      .catch((e) => setError(e instanceof Error ? e.message : String(e)));
  }

  if (previewing) {
    return (
      <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
        <button
          type="button"
          onClick={() => setPreviewing(null)}
          style={{
            margin: "8px 12px",
            padding: "6px 12px",
            alignSelf: "flex-start",
            background: "transparent",
            border: "1px solid var(--card-border)",
            borderRadius: 6,
            color: "var(--text-muted)",
            cursor: "pointer",
            fontSize: 13,
          }}
        >
          ← {previewing.name}
        </button>
        {error ? (
          <p style={{ padding: 24, color: "var(--stalled-red)", fontSize: 12 }}>
            Failed to load: {error}
          </p>
        ) : (
          <CardDetailMarkdownPane content={previewContent} />
        )}
      </div>
    );
  }

  return (
    <ul className="design-folder-index" data-testid="design-folder-index">
      {files.map((file) => {
        const isMarkdown = file.name.endsWith(".md");
        const isHtml = file.name.endsWith(".html");
        return (
          <li key={file.path} className="design-folder-index__row">
            <span className="design-folder-index__name">{file.name}</span>
            {isMarkdown && (
              <button
                type="button"
                className="design-folder-index__reveal-btn"
                onClick={() => handlePreview(file)}
              >
                Preview
              </button>
            )}
            {isHtml && (
              <button
                type="button"
                className="design-folder-index__reveal-btn"
                onClick={() => handleOpen(file.path)}
              >
                Open in browser
              </button>
            )}
            <button
              type="button"
              className="design-folder-index__reveal-btn"
              onClick={() => handleReveal(file.path)}
            >
              {t("btn.revealInFinder")}
            </button>
          </li>
        );
      })}
    </ul>
  );
}

export default DesignFolderIndex;
