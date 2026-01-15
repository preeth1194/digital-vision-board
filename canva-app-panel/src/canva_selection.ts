import type { SelectedItem } from "./types";

type Unsubscribe = () => void;

function safeJsonPreview(value: unknown, maxLen = 1200): unknown {
  try {
    const s = JSON.stringify(value);
    if (s.length <= maxLen) return value;
    return `${s.slice(0, maxLen)}…`;
  } catch {
    return String(value);
  }
}

function stableKeyFromUnknown(x: unknown): string {
  try {
    // Avoid huge keys; this is only for client-side mapping.
    const s = JSON.stringify(x);
    let h = 0;
    for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
    return `sel_${Math.abs(h)}`;
  } catch {
    return `sel_${Date.now()}`;
  }
}

function inferKind(scope: string): SelectedItem["kind"] {
  if (scope === "image") return "image";
  if (scope === "video") return "video";
  if (scope === "plaintext") return "plaintext";
  if (scope === "richtext") return "richtext";
  return "unknown";
}

/**
 * Best-effort selection listener.
 *
 * - Inside Canva: uses the Apps SDK selection API if available.
 * - Outside Canva (local dev): returns a no-op unsubscribe and never updates.
 */
export async function registerSelectionListener(
  onUpdate: (items: SelectedItem[]) => void,
): Promise<Unsubscribe> {
  try {
    const designMod: any = await import("@canva/design");
    const selection = designMod?.selection;
    if (!selection?.registerOnChange) return () => {};

    const scopes = ["image", "video", "plaintext", "richtext"] as const;
    const unsubs: Unsubscribe[] = [];
    const latestByScope = new Map<string, SelectedItem[]>();

    const emit = () => {
      const all = scopes.flatMap((s) => latestByScope.get(s) ?? []);
      onUpdate(all);
    };

    for (const scope of scopes) {
      const unsub = selection.registerOnChange({
        scope,
        onChange: async (event: any) => {
          try {
            if (!event || typeof event.count !== "number" || event.count <= 0) {
              latestByScope.set(scope, []);
              emit();
              return;
            }

            const draft = await event.read?.();
            const contents = Array.isArray(draft?.contents) ? draft.contents : [];
            const items: SelectedItem[] = contents.map((c: any, idx: number) => {
              const ref = c?.ref ?? c?.assetRef ?? c?.mediaRef;
              const text = c?.text;
              const key =
                typeof ref === "string"
                  ? ref
                  : typeof text === "string"
                    ? `text_${text.slice(0, 64)}_${idx}`
                    : stableKeyFromUnknown(c);

              return {
                key,
                kind: inferKind(scope),
                raw: safeJsonPreview(c),
              };
            });
            latestByScope.set(scope, items);
            emit();
          } catch {
            // If selection read fails for this scope, ignore updates.
          }
        },
      });
      if (typeof unsub === "function") unsubs.push(unsub);
    }

    return () => {
      for (const u of unsubs) u();
    };
  } catch {
    return () => {};
  }
}

/**
 * Best-effort read of current page elements (for optional geometry enrichment).
 * If the Design Editing API isn’t available (or we’re not inside Canva), returns [].
 */
export async function tryReadCurrentPageElements(): Promise<
  Array<{ id?: string; type?: string; top?: number; left?: number; width?: number; height?: number; rotation?: number }>
> {
  try {
    const designMod: any = await import("@canva/design");
    const openDesign = designMod?.openDesign;
    if (!openDesign) return [];

    let result: any[] = [];
    await openDesign({ type: "current_page" }, async (session: any) => {
      const elements =
        session?.page?.elements?.toArray?.() ??
        session?.page?.elements ??
        session?.page?.children?.toArray?.() ??
        session?.page?.children ??
        [];
      result = Array.isArray(elements) ? elements : [];
    });

    return result.map((el: any) => ({
      id: typeof el?.id === "string" ? el.id : undefined,
      type: typeof el?.type === "string" ? el.type : undefined,
      top: typeof el?.top === "number" ? el.top : undefined,
      left: typeof el?.left === "number" ? el.left : undefined,
      width: typeof el?.width === "number" ? el.width : undefined,
      height: typeof el?.height === "number" ? el.height : undefined,
      rotation: typeof el?.rotation === "number" ? el.rotation : undefined,
    }));
  } catch {
    return [];
  }
}

