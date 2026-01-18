import type { CanvaPageElement, SelectedItem } from "./types";

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
  CanvaPageElement[]
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

    const pickString = (...vals: any[]): string | undefined => {
      for (const v of vals) {
        if (typeof v === "string" && v.trim()) return v;
      }
      return undefined;
    };

    const pickNum = (...vals: any[]): number | undefined => {
      for (const v of vals) {
        if (typeof v === "number" && Number.isFinite(v)) return v;
      }
      return undefined;
    };

    return result.map((el: any) => {
      // Best-effort: Canva element shapes vary by SDK/version. Keep this defensive.
      const text = pickString(el?.text, el?.plainText, el?.content?.text, el?.data?.text);

      const styleSrc = el?.style ?? el?.textStyle ?? el?.data?.style ?? el ?? {};
      const style =
        text != null
          ? {
              color: styleSrc?.color ?? styleSrc?.textColor ?? styleSrc?.fillColor,
              fontSize: pickNum(styleSrc?.fontSize, styleSrc?.size),
              fontWeight: pickNum(styleSrc?.fontWeight),
              fontStyle: pickNum(styleSrc?.fontStyle),
              fontFamily: pickString(styleSrc?.fontFamily, styleSrc?.family),
              textAlign: styleSrc?.textAlign ?? styleSrc?.align,
            }
          : undefined;

      return {
        id: typeof el?.id === "string" ? el.id : undefined,
        type: typeof el?.type === "string" ? el.type : undefined,
        top: pickNum(el?.top, el?.y),
        left: pickNum(el?.left, el?.x),
        width: pickNum(el?.width, el?.w),
        height: pickNum(el?.height, el?.h),
        rotation: pickNum(el?.rotation),
        text,
        style,
      } satisfies CanvaPageElement;
    });
  } catch {
    return [];
  }
}

