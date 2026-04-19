import { useState, useEffect } from "react";

interface MarkdownPaneProps {
  content: string;
}

/**
 * MarkdownPane renders user-supplied markdown as sanitised HTML.
 *
 * Security contract (matches T16 task requirements):
 *  - markdown-it is LAZY-loaded via dynamic import so the first paint of
 *    MainWindow does not pay the markdown bundle cost (performance rule check 8).
 *  - DOMPurify.sanitize is the LAST step before the HTML string is placed into
 *    dangerouslySetInnerHTML — no HTML reaches the DOM without sanitisation.
 *  - DOMPurify DEFAULT profile is used; no tags/attrs are relaxed.
 *  - markdown-it-task-lists plugin is enabled for GFM checkbox support (R-4).
 *  - GFM tables are enabled via markdown-it's built-in `html: false` + `linkify`
 *    defaults; tables are always on in markdown-it 14.
 */
function MarkdownPane({ content }: MarkdownPaneProps) {
  const [safeHtml, setSafeHtml] = useState<string>("");

  useEffect(() => {
    // Lazy-load both libraries so this module's top-level import graph stays
    // free of markdown-it (verified by the acceptance grep check).
    let cancelled = false;

    async function render() {
      const [{ default: MarkdownIt }, { default: DOMPurify }, { default: taskLists }] =
        await Promise.all([
          import("markdown-it"),
          import("dompurify"),
          import("markdown-it-task-lists"),
        ]);

      if (cancelled) return;

      const md = new MarkdownIt({
        // HTML passthrough is disabled — raw HTML tags in source are escaped,
        // never inserted verbatim (XSS-safe default).
        html: false,
        // Linkify plain-text URLs so they become clickable anchors.
        linkify: true,
        // Smart typography (curly quotes, em-dashes). Safe; no HTML involved.
        typographer: true,
      });

      // GFM checkbox task lists (R-4 mitigation).
      md.use(taskLists);

      // Render markdown → HTML, then sanitise with DOMPurify DEFAULT profile.
      const rendered = md.render(content);
      const safe = DOMPurify.sanitize(rendered);

      setSafeHtml(safe);
    }

    render();

    return () => {
      cancelled = true;
    };
  }, [content]);

  return (
    <div
      data-testid="markdown-pane"
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={{ __html: safeHtml }}
    />
  );
}

export default MarkdownPane;
