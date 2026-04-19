import { invoke } from "@tauri-apps/api/core";
import { useTranslation } from "../i18n";

export interface DesignFile {
  name: string;
  path: string;
}

interface DesignFolderIndexProps {
  files: DesignFile[];
}

/**
 * DesignFolderIndex — read-only file index for the 02-design tab.
 *
 * AC9.h: each row has exactly ONE action — "Reveal in Finder" — which calls
 * the `reveal_in_finder` IPC stub (wired to `open -R <path>` on macOS in T35).
 *
 * B2 boundary: NO edit, NO delete, NO preview-modal affordance.
 * The header-strip "Open in Finder" button (CardDetailHeader) opens the
 * feature directory; this component opens individual sub-files in Finder.
 */
export function DesignFolderIndex({ files }: DesignFolderIndexProps) {
  const { t } = useTranslation();

  function handleReveal(path: string) {
    // T35 will wire this to `open -R <path>` on macOS.
    // The stub in ipc.rs currently returns Err("not yet implemented").
    void invoke("reveal_in_finder", { path });
  }

  return (
    <ul className="design-folder-index" data-testid="design-folder-index">
      {files.map((file) => (
        <li key={file.path} className="design-folder-index__row">
          <span className="design-folder-index__name">{file.name}</span>
          <button
            type="button"
            className="design-folder-index__reveal-btn"
            onClick={() => handleReveal(file.path)}
          >
            {t("btn.revealInFinder")}
          </button>
        </li>
      ))}
    </ul>
  );
}

export default DesignFolderIndex;
