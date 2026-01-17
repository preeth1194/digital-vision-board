import React, { useEffect, useMemo, useState } from "react";
import { Button, Rows, Text, TextInput, Title } from "@canva/app-ui-kit";
import { fetchHabits, getDvToken, postAdminCanvaImportCurrentPage, postAdminCreateTemplate, postSync, setDvToken } from "./api";
import { backendBaseUrl } from "./env";
import { registerSelectionListener, tryReadCurrentPageElements } from "./canva_selection";
import type { Habit, Mapping, SelectedItem } from "./types";
import { requestOpenExternalUrl } from "@canva/platform";

type Status = { kind: "idle" } | { kind: "loading" } | { kind: "error"; message: string } | { kind: "ok"; message: string };

export function App() {
  const [dvToken, setDvTokenState] = useState<string>(() => getDvToken());
  const [habits, setHabits] = useState<Habit[]>([]);
  const [habitsStatus, setHabitsStatus] = useState<Status>({ kind: "idle" });

  const [selection, setSelection] = useState<SelectedItem[]>([]);
  const [selectionStatus, setSelectionStatus] = useState<Status>({ kind: "idle" });

  const [selectedHabitId, setSelectedHabitId] = useState<string>("");
  const [mappings, setMappings] = useState<Record<string, string>>({});

  const [syncStatus, setSyncStatus] = useState<Status>({ kind: "idle" });
  const [templatesStatus, setTemplatesStatus] = useState<Status>({ kind: "idle" });
  const [templateName, setTemplateName] = useState<string>("Canva Import");
  const [pendingTemplateJson, setPendingTemplateJson] = useState<any>(null);
  const [showDebug, setShowDebug] = useState(false);

  const habitById = useMemo(() => new Map(habits.map((h) => [h.id, h])), [habits]);
  const mappedCount = useMemo(() => Object.keys(mappings).length, [mappings]);

  useEffect(() => {
    function onMessage(ev: MessageEvent) {
      const data: any = ev.data;
      if (!data || data.type !== "dv_canva_oauth_success") return;
      if (typeof data.dvToken !== "string" || !data.dvToken) return;
      setDvToken(data.dvToken);
      setDvTokenState(data.dvToken);
      setSyncStatus({ kind: "ok", message: "Connected to backend." });
    }
    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, []);

  useEffect(() => {
    let unsub: (() => void) | undefined;
    (async () => {
      setSelectionStatus({ kind: "loading" });
      unsub = await registerSelectionListener((items) => {
        setSelection(items);
        setSelectionStatus({ kind: "ok", message: `Selection: ${items.length} item(s)` });
      });
      setSelectionStatus({ kind: "ok", message: "Listening for selection…" });
    })();
    return () => unsub?.();
  }, []);

  async function loadHabits() {
    setHabitsStatus({ kind: "loading" });
    try {
      if (!getDvToken()) throw new Error("Not connected. Click “Connect to Digital Vision Board” first.");
      const hs = await fetchHabits();
      setHabits(hs);
      setSelectedHabitId((prev) => (prev ? prev : hs[0]?.id ?? ""));
      setHabitsStatus({ kind: "ok", message: `Loaded ${hs.length} habit(s)` });
    } catch (e: any) {
      setHabitsStatus({ kind: "error", message: e?.message ?? String(e) });
    }
  }

  function attachHabitToSelection() {
    if (!selectedHabitId) {
      setSyncStatus({ kind: "error", message: "Pick a habit first." });
      return;
    }
    if (selection.length === 0) {
      setSyncStatus({ kind: "error", message: "Select something in Canva first." });
      return;
    }
    setMappings((prev) => {
      const next = { ...prev };
      for (const item of selection) next[item.key] = selectedHabitId;
      return next;
    });
    setSyncStatus({ kind: "ok", message: `Attached habit to ${selection.length} selected item(s).` });
  }

  async function enrichSelectionWithGeometry() {
    setSelectionStatus({ kind: "loading" });
    try {
      const els = await tryReadCurrentPageElements();
      if (els.length === 0) {
        setSelectionStatus({ kind: "ok", message: "No element geometry available (outside Canva / unsupported)." });
        return;
      }
      // We can’t reliably map selection→element, so we only show geometry as a hint.
      // This keeps the payload stable (selection keys still drive mappings).
      setSelection((prev) =>
        prev.map((s, i) => ({
          ...s,
          bounds:
            s.bounds ??
            (els[i]
              ? {
                  left: els[i].left,
                  top: els[i].top,
                  width: els[i].width,
                  height: els[i].height,
                  rotation: els[i].rotation,
                }
              : undefined),
          elementId: s.elementId ?? els[i]?.id,
        })),
      );
      setSelectionStatus({ kind: "ok", message: `Enriched with ${Math.min(selection.length, els.length)} element(s).` });
    } catch (e: any) {
      setSelectionStatus({ kind: "error", message: e?.message ?? String(e) });
    }
  }

  async function sync() {
    setSyncStatus({ kind: "loading" });
    try {
      if (!getDvToken()) throw new Error("Not connected. Click “Connect to Digital Vision Board” first.");
      let designToken = "";
      try {
        const designMod: any = await import("@canva/design");
        const getDesignToken = designMod?.getDesignToken;
        const tokenObj = (await getDesignToken?.()) ?? null;
        designToken = typeof tokenObj?.token === "string" ? tokenObj.token : "";
      } catch {
        // outside Canva / SDK unavailable
      }
      if (!designToken) throw new Error("Could not read Canva design token. Make sure you are running inside Canva.");

      const payloadMappings: Mapping[] = Object.entries(mappings).map(([key, habitId]) => ({ key, habitId }));
      await postSync({
        version: 1,
        sentAt: new Date().toISOString(),
        designToken,
        mappings: payloadMappings,
        selection,
      });
      setSyncStatus({ kind: "ok", message: "Synced to backend." });
    } catch (e: any) {
      setSyncStatus({ kind: "error", message: e?.message ?? String(e) });
    }
  }

  async function importCurrentPageAsTemplate() {
    setTemplatesStatus({ kind: "loading" });
    try {
      if (!getDvToken()) throw new Error("Not connected. Click “Connect to Digital Vision Board” first.");
      let designToken = "";
      try {
        const designMod: any = await import("@canva/design");
        const getDesignToken = designMod?.getDesignToken;
        const tokenObj = (await getDesignToken?.()) ?? null;
        designToken = typeof tokenObj?.token === "string" ? tokenObj.token : "";
      } catch {
        // outside Canva / SDK unavailable
      }
      if (!designToken) throw new Error("Could not read Canva design token. Make sure you are running inside Canva.");

      const els = await tryReadCurrentPageElements();
      if (!els.length) throw new Error("Could not read page elements. Make sure the Design Editing API is available.");
      const elements = els
        .filter(
          (e) => typeof e.left === "number" && typeof e.top === "number" && typeof e.width === "number" && typeof e.height === "number",
        )
        .map((e) => ({
          id: e.id,
          type: e.type,
          left: e.left!,
          top: e.top!,
          width: e.width!,
          height: e.height!,
          rotation: e.rotation,
          text: typeof e.text === "string" ? e.text : undefined,
          style: typeof (e as any).style === "object" && (e as any).style ? (e as any).style : undefined,
        }));

      const imported = await postAdminCanvaImportCurrentPage({ designToken, elements });
      const templateJson = imported?.template?.templateJson ?? null;
      if (!templateJson || typeof templateJson !== "object") throw new Error("Import returned no templateJson.");

      setPendingTemplateJson(templateJson);
      setTemplatesStatus({ kind: "ok", message: "Import done. Review name and publish below." });
    } catch (e: any) {
      setTemplatesStatus({ kind: "error", message: e?.message ?? String(e) });
    }
  }

  async function publishPendingTemplate() {
    setTemplatesStatus({ kind: "loading" });
    try {
      const name = templateName.trim();
      if (!name) throw new Error("Template name is required.");
      const templateJson = pendingTemplateJson;
      if (!templateJson || typeof templateJson !== "object") throw new Error("No imported template to publish yet.");

      // Best-effort preview image: parse first component image id from '/template-images/<id>'
      let previewImageId: string | null = null;
      const comps: any[] = Array.isArray((templateJson as any)?.components) ? (templateJson as any).components : [];
      const firstPath = typeof comps[0]?.imagePath === "string" ? comps[0].imagePath : "";
      if (firstPath.startsWith("/template-images/")) {
        previewImageId = firstPath.split("/").filter(Boolean)[1] ?? null;
      }

      const created = await postAdminCreateTemplate({
        name,
        kind: "goal_canvas",
        templateJson,
        previewImageId,
      });
      setPendingTemplateJson(null);
      setTemplatesStatus({ kind: "ok", message: `Published template: ${created?.id ?? "ok"}` });
    } catch (e: any) {
      setTemplatesStatus({ kind: "error", message: e?.message ?? String(e) });
    }
  }

  async function connectToBackend() {
    setSyncStatus({ kind: "loading" });
    try {
      const startRes = await fetch(`${backendBaseUrl()}/auth/canva/start_poll`, {
        method: "GET",
        headers: { Accept: "application/json" },
      });
      const startText = await startRes.text().catch(() => "");
      if (!startRes.ok) throw new Error(`Start auth failed (${startRes.status}): ${startText || startRes.statusText}`);
      const startJson = startText ? (JSON.parse(startText) as any) : {};
      const authUrl = String(startJson?.authUrl ?? "");
      const pollToken = String(startJson?.pollToken ?? "");
      if (!authUrl || !pollToken) throw new Error("Auth start response missing authUrl/pollToken.");

      await requestOpenExternalUrl({ url: authUrl });

      const deadline = Date.now() + 2 * 60 * 1000;
      while (Date.now() < deadline) {
        await new Promise((r) => setTimeout(r, 1200));
        const pollRes = await fetch(
          `${backendBaseUrl()}/auth/canva/poll?pollToken=${encodeURIComponent(pollToken)}`,
          { method: "GET", headers: { Accept: "application/json" } },
        );
        const pollText = await pollRes.text().catch(() => "");
        if (!pollRes.ok) continue;
        const pollJson = pollText ? (JSON.parse(pollText) as any) : {};
        if (pollJson?.status === "completed" && typeof pollJson?.dvToken === "string" && pollJson.dvToken) {
          setDvToken(pollJson.dvToken);
          setDvTokenState(pollJson.dvToken);
          setSyncStatus({ kind: "ok", message: "Connected to backend." });
          return;
        }
      }
      throw new Error("Timed out waiting for authentication to complete.");
    } catch (e: any) {
      setSyncStatus({ kind: "error", message: e?.message ?? String(e) });
    }
  }

  const selectionWithMapping = selection.map((s) => ({
    ...s,
    habitId: mappings[s.key],
  }));

  const panelStyle: React.CSSProperties = {
    border: "1px solid rgba(0,0,0,0.12)",
    borderRadius: 12,
    padding: 12,
    background: "rgba(255,255,255,0.8)",
  };

  return (
    <div style={{ padding: 12 }}>
      <Rows spacing="2u">
        <Title>Digital Vision Board</Title>
        <Text>Map selected Canva content to a habit, then sync to your backend.</Text>

        <div style={panelStyle}>
          <Rows spacing="2u">
            <Title size="small">Backend</Title>
            <Text size="small">Base URL: {backendBaseUrl()}</Text>
            <Text size="small">
              Status: {dvToken ? "Connected" : "Not connected"}
            </Text>
            <Rows spacing="1u">
              <Button
                variant="secondary"
                onClick={connectToBackend}
              >
                Connect to Digital Vision Board
              </Button>
              {dvToken ? (
                <Button
                  variant="tertiary"
                  onClick={() => {
                    setDvToken("");
                    setDvTokenState("");
                    setSyncStatus({ kind: "ok", message: "Disconnected." });
                  }}
                >
                  Disconnect
                </Button>
              ) : null}
            </Rows>
          </Rows>
        </div>

        <div style={panelStyle}>
          <Rows spacing="2u">
            <Title size="small">Habits</Title>
            <Rows spacing="1u">
              <Button variant="secondary" onClick={loadHabits}>
                Load habits
              </Button>
              <Text size="small">{habitsStatus.kind === "error" ? habitsStatus.message : habitsStatus.kind === "ok" ? habitsStatus.message : ""}</Text>
            </Rows>

            <label style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              <Text size="small">Selected habit</Text>
              <select value={selectedHabitId} onChange={(e) => setSelectedHabitId(e.target.value)} style={{ padding: 8 }}>
                <option value="" disabled>
                  {habits.length ? "Select a habit" : "Load habits first"}
                </option>
                {habits.map((h) => (
                  <option key={h.id} value={h.id}>
                    {h.name}
                  </option>
                ))}
              </select>
            </label>
          </Rows>
        </div>

        <div style={panelStyle}>
          <Rows spacing="2u">
            <Title size="small">Templates (admin)</Title>
            <Text size="small">Imports current Canva page as a Goal Canvas template via backend cropping.</Text>
            <Rows spacing="1u">
              <Button variant="primary" onClick={importCurrentPageAsTemplate}>
                Import current page as template
              </Button>
              <Text size="small">Template name</Text>
              <TextInput value={templateName} onChange={(e: any) => setTemplateName(String(e?.target?.value ?? ""))} />
              <Button variant="secondary" disabled={!pendingTemplateJson} onClick={publishPendingTemplate}>
                Publish imported template
              </Button>
              <Text size="small">
                {templatesStatus.kind === "error"
                  ? templatesStatus.message
                  : templatesStatus.kind === "ok"
                    ? templatesStatus.message
                    : templatesStatus.kind === "loading"
                      ? "Working…"
                      : ""}
              </Text>
            </Rows>
          </Rows>
        </div>

        <div style={panelStyle}>
          <Rows spacing="2u">
            <Title size="small">Selection</Title>
            <Rows spacing="1u">
              <Button variant="secondary" onClick={enrichSelectionWithGeometry}>
                Try enrich with geometry
              </Button>
              <Button variant="primary" onClick={attachHabitToSelection}>
                Attach habit to selection
              </Button>
            </Rows>

            <Text size="small">
              {selectionStatus.kind === "error"
                ? selectionStatus.message
                : selectionStatus.kind === "ok"
                  ? selectionStatus.message
                  : selectionStatus.kind === "loading"
                    ? "Loading…"
                    : ""}
            </Text>

            {selectionWithMapping.length === 0 ? (
              <Text size="small">Nothing selected. Select text or an image/video in Canva.</Text>
            ) : (
              <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                {selectionWithMapping.map((s) => {
                  const mapped = s.habitId ? habitById.get(s.habitId)?.name ?? s.habitId : "";
                  const b = s.bounds;
                  return (
                    <div key={s.key} style={{ border: "1px solid rgba(0,0,0,0.12)", borderRadius: 8, padding: 10 }}>
                      <Text size="small">
                        <strong>{s.kind}</strong> • key: <code>{s.key}</code>
                      </Text>
                      {s.elementId ? (
                        <Text size="small">
                          elementId: <code>{s.elementId}</code>
                        </Text>
                      ) : null}
                      {b?.left != null && b?.top != null && b?.width != null && b?.height != null ? (
                        <Text size="small">
                          bounds: {Math.round(b.left)},{Math.round(b.top)} {Math.round(b.width)}×{Math.round(b.height)}
                          {b.rotation != null ? ` r=${Math.round(b.rotation)}` : ""}
                        </Text>
                      ) : null}
                      <Text size="small">habit: {mapped || "(none)"}</Text>
                    </div>
                  );
                })}
              </div>
            )}

            <Button variant="tertiary" onClick={() => setShowDebug((v) => !v)}>
              {showDebug ? "Hide debug" : "Show debug"}
            </Button>
            {showDebug ? (
              <pre style={{ margin: 0, maxHeight: 220, overflow: "auto", fontSize: 11, padding: 10, background: "rgba(0,0,0,0.04)", borderRadius: 8 }}>
                {JSON.stringify({ selection, mappings }, null, 2)}
              </pre>
            ) : null}
          </Rows>
        </div>

        <div style={panelStyle}>
          <Rows spacing="2u">
            <Title size="small">Sync</Title>
            <Text size="small">
              Mapped items: {mappedCount} • Selected items: {selection.length}
            </Text>
            <Button variant="primary" onClick={sync}>
              Sync board to app
            </Button>
            <Text size="small">
              {syncStatus.kind === "error"
                ? syncStatus.message
                : syncStatus.kind === "ok"
                  ? syncStatus.message
                  : syncStatus.kind === "loading"
                    ? "Syncing…"
                    : ""}
            </Text>
          </Rows>
        </div>
      </Rows>
    </div>
  );
}

