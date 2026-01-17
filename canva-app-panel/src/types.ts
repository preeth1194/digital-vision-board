export type Habit = {
  id: string;
  name: string;
};

export type ElementBounds = {
  left?: number;
  top?: number;
  width?: number;
  height?: number;
  rotation?: number;
};

export type CanvaPageElement = {
  id?: string;
  type?: string;
  left?: number;
  top?: number;
  width?: number;
  height?: number;
  rotation?: number;
  // Optional text metadata (best-effort; only present for text-like elements).
  text?: string;
  style?: {
    // These map 1:1 to Flutter VisionComponent.textStyleToJson keys where possible.
    color?: number | string | { r?: number; g?: number; b?: number; a?: number };
    fontSize?: number;
    fontWeight?: number;
    fontStyle?: number;
    fontFamily?: string;
    textAlign?: number | string;
  };
};

export type SelectedItem = {
  /**
   * Best-effort stable key to identify a selected thing.
   * For images/videos this may be a Canva ref; for text it may be a hash-like string.
   */
  key: string;
  /** Human-readable type/category for UI. */
  kind: "image" | "video" | "plaintext" | "richtext" | "unknown";
  /** Canva element id if we can infer it; may be missing. */
  elementId?: string;
  /** Bounds in Canva canvas space if available; may be missing. */
  bounds?: ElementBounds;
  /** Raw selection payload for debugging (kept small). */
  raw?: unknown;
};

export type Mapping = {
  key: string; // SelectedItem.key
  habitId: string;
};

