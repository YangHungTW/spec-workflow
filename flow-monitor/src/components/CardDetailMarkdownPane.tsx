import MarkdownPane from "./MarkdownPane";

interface CardDetailMarkdownPaneProps {
  content: string;
}

/**
 * CardDetailMarkdownPane — XSS-safe markdown renderer for the CardDetail right pane.
 *
 * Wraps T16's <MarkdownPane> and appends a read-only footer.
 *
 * AC9.e: no edit affordance — the pane is display-only; no contenteditable,
 *        no Save/Edit button, no command trigger.
 */
function CardDetailMarkdownPane({ content }: CardDetailMarkdownPaneProps) {
  return (
    <div className="card-detail__markdown">
      <MarkdownPane content={content} />
      {/*
       * AC9.k: literal footer per PRD §9 carve-out — NOT i18n'd by design.
       * The exact string "Read-only preview. Open in Finder to edit." is the
       * acceptance criterion text; using t() here would break the AC9.k
       * string-match test (even when zh-TW locale is active, this stays English).
       */}
      <footer className="card-detail__markdown-footer">
        Read-only preview. Open in Finder to edit.
      </footer>
    </div>
  );
}

export default CardDetailMarkdownPane;
