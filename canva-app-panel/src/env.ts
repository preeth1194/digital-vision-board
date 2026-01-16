export function backendBaseUrl(): string {
  const raw = import.meta.env.VITE_BACKEND_BASE_URL as string | undefined;
  if (!raw) return "https://digital-vision-board.onrender.com";
  return raw.replace(/\/+$/, "");
}

