import type { Habit, Mapping, SelectedItem } from "./types";
import { backendBaseUrl } from "./env";

export function getDvToken(): string {
  try {
    return localStorage.getItem("dvToken") ?? "";
  } catch {
    return "";
  }
}

export function setDvToken(token: string): void {
  try {
    if (!token) localStorage.removeItem("dvToken");
    else localStorage.setItem("dvToken", token);
  } catch {
    // ignore
  }
}

function authHeaders(): Record<string, string> {
  const dvToken = getDvToken();
  return dvToken ? { Authorization: `Bearer ${dvToken}` } : {};
}

export async function fetchHabits(): Promise<Habit[]> {
  const res = await fetch(`${backendBaseUrl()}/habits`, {
    method: "GET",
    headers: { Accept: "application/json", ...authHeaders() },
  });
  if (!res.ok) throw new Error(`Failed to load habits (${res.status})`);
  const data = (await res.json()) as unknown;

  // Accept { habits: [...] } (backend), or array fallback.
  const list = Array.isArray((data as any)?.habits) ? (data as any).habits : Array.isArray(data) ? data : [];
  return list
    .map((h: any) => ({
      id: String(h.id ?? h.habitId ?? h.key ?? ""),
      name: String(h.name ?? h.title ?? h.label ?? ""),
    }))
    .filter((h: Habit) => h.id && h.name);
}

export type SyncPayload = {
  version: 1;
  sentAt: string;
  designToken: string;
  mappings: Mapping[];
  selection: SelectedItem[];
};

export async function postSync(payload: SyncPayload): Promise<void> {
  const res = await fetch(`${backendBaseUrl()}/canva/sync`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...authHeaders(),
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`Sync failed (${res.status}): ${text || res.statusText}`);
  }
}

export async function postAdminCanvaImportCurrentPage(payload: {
  designToken: string;
  elements: Array<{
    id?: string;
    type?: string;
    left: number;
    top: number;
    width: number;
    height: number;
    rotation?: number;
    text?: string;
    style?: any;
  }>;
}): Promise<any> {
  const res = await fetch(`${backendBaseUrl()}/admin/canva/import/current-page`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...authHeaders(),
    },
    body: JSON.stringify(payload),
  });
  const text = await res.text().catch(() => "");
  if (!res.ok) throw new Error(`Import failed (${res.status}): ${text || res.statusText}`);
  return text ? JSON.parse(text) : {};
}

export async function postAdminCreateTemplate(payload: {
  name: string;
  kind: "goal_canvas" | "grid";
  templateJson: any;
  previewImageId?: string | null;
}): Promise<any> {
  const res = await fetch(`${backendBaseUrl()}/admin/templates`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...authHeaders(),
    },
    body: JSON.stringify(payload),
  });
  const text = await res.text().catch(() => "");
  if (!res.ok) throw new Error(`Create template failed (${res.status}): ${text || res.statusText}`);
  return text ? JSON.parse(text) : {};
}
