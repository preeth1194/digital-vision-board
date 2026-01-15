export function backendBaseUrl(): string {
  const raw = import.meta.env.VITE_BACKEND_BASE_URL as string | undefined;
  if (!raw) return "http://localhost:8787";
  return raw.replace(/\/+$/, "");
}

