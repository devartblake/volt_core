// Pure recursive walker over a Storage "list" function (injected, so it is
// testable without Supabase). Supabase Storage lists one folder level at a
// time; folders come back with id === null.

export type ListEntry = {
  name: string;
  id: string | null;
  created_at: string | null;
};

export type ListFn = (
  prefix: string,
  offset: number,
  limit: number,
) => Promise<ListEntry[]>;

export type WalkResult = {
  objects: Array<{ name: string; created_at: string | null }>;
  /** True when maxObjects (or the depth guard) stopped the walk early. */
  truncated: boolean;
};

export async function walkStorage(
  list: ListFn,
  rootPrefix: string,
  options: { maxObjects: number; pageSize?: number; maxDepth?: number },
): Promise<WalkResult> {
  const pageSize = options.pageSize ?? 100;
  const maxDepth = options.maxDepth ?? 8;
  const objects: WalkResult["objects"] = [];
  let truncated = false;

  async function visit(prefix: string, depth: number): Promise<void> {
    if (depth > maxDepth) {
      truncated = true;
      return;
    }
    let offset = 0;
    for (;;) {
      const page = await list(prefix, offset, pageSize);
      for (const e of page) {
        const full = prefix === "" ? e.name : `${prefix}/${e.name}`;
        if (e.id === null) {
          await visit(full, depth + 1);
        } else {
          if (objects.length >= options.maxObjects) {
            truncated = true;
            return;
          }
          objects.push({ name: full, created_at: e.created_at });
        }
        if (truncated) return;
      }
      if (page.length < pageSize) return;
      offset += pageSize;
    }
  }

  await visit(rootPrefix.replace(/\/+$/, ""), 0);
  return { objects, truncated };
}
