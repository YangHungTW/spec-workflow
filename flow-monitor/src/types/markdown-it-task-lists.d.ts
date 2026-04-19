// Type declaration for markdown-it-task-lists (no @types package available).
// The plugin conforms to the markdown-it plugin interface: it receives the
// MarkdownIt instance and an optional options object.
declare module "markdown-it-task-lists" {
  import type MarkdownIt from "markdown-it";
  interface TaskListsOptions {
    enabled?: boolean;
    label?: boolean;
    labelAfter?: boolean;
  }
  const taskLists: (md: MarkdownIt, options?: TaskListsOptions) => void;
  export default taskLists;
}
