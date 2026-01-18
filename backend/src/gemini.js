function requireEnv(name) {
  const v = String(process.env[name] ?? "").trim();
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

function clampInt(n, min, max) {
  const x = Number.isFinite(n) ? Math.trunc(n) : null;
  if (x == null) return null;
  return Math.max(min, Math.min(max, x));
}

function asNonEmptyString(v) {
  const s = typeof v === "string" ? v.trim() : "";
  return s ? s : null;
}

function sanitizeCbt(cbt) {
  if (!cbt || typeof cbt !== "object") return null;
  const out = {
    microVersion: asNonEmptyString(cbt.microVersion ?? cbt.micro_version),
    predictedObstacle: asNonEmptyString(cbt.predictedObstacle ?? cbt.predicted_obstacle),
    ifThenPlan: asNonEmptyString(cbt.ifThenPlan ?? cbt.if_then_plan),
    confidenceScore: clampInt(
      typeof cbt.confidenceScore === "number" ? cbt.confidenceScore : Number(cbt.confidence_score),
      0,
      10,
    ),
    reward: asNonEmptyString(cbt.reward),
  };
  const hasAny =
    out.microVersion || out.predictedObstacle || out.ifThenPlan || out.confidenceScore != null || out.reward;
  return hasAny ? out : null;
}

function sanitizeHabit(h) {
  if (!h || typeof h !== "object") return null;
  const name = asNonEmptyString(h.name ?? h.title);
  if (!name) return null;
  const frequencyRaw = asNonEmptyString(h.frequency);
  const frequency =
    frequencyRaw && ["daily", "weekly"].includes(frequencyRaw.toLowerCase())
      ? frequencyRaw[0].toUpperCase() + frequencyRaw.slice(1).toLowerCase()
      : "Daily";
  return {
    name,
    frequency,
    cbtEnhancements: sanitizeCbt(h.cbtEnhancements ?? h.cbt_enhancements),
  };
}

function sanitizeGoal(g) {
  if (!g || typeof g !== "object") return null;
  const name = asNonEmptyString(g.name ?? g.title);
  if (!name) return null;
  const whyImportant =
    asNonEmptyString(g.whyImportant ?? g.why_important ?? g.why ?? g.reason ?? g.rationale) ?? "";
  const habitsRaw = Array.isArray(g.habits)
    ? g.habits
    : Array.isArray(g.recommendedHabits)
      ? g.recommendedHabits
      : Array.isArray(g.recommended_habits)
        ? g.recommended_habits
        : [];
  const habits = habitsRaw.map(sanitizeHabit).filter(Boolean);
  return { name, whyImportant, habits };
}

function sleepMs(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseRetryDelayMs(rawText) {
  try {
    const j = JSON.parse(rawText);
    const details = Array.isArray(j?.error?.details) ? j.error.details : [];
    for (const d of details) {
      const type = d?.["@type"];
      if (type === "type.googleapis.com/google.rpc.RetryInfo") {
        const s = String(d?.retryDelay ?? "").trim(); // e.g. "23s"
        const m = /^(\d+(?:\.\d+)?)s$/.exec(s);
        if (m) return Math.max(0, Math.round(parseFloat(m[1]) * 1000));
      }
    }
  } catch {}
  return null;
}

function extractGoalsArray(json) {
  if (!json) return null;
  // Common case: { goals: [...] }
  if (Array.isArray(json.goals)) return json.goals;
  // Sometimes: { recommendations: { goals: [...] } }
  if (json.recommendations && Array.isArray(json.recommendations.goals)) return json.recommendations.goals;
  // Sometimes: { recommendations: [...] } (array of goals)
  if (Array.isArray(json.recommendations)) return json.recommendations;
  // Sometimes: { items: [...] } or { suggestions: [...] }
  if (Array.isArray(json.items)) return json.items;
  if (Array.isArray(json.suggestions)) return json.suggestions;
  // Sometimes the model returns the array directly.
  if (Array.isArray(json)) return json;
  // One more nesting level (defensive)
  if (json.data && Array.isArray(json.data.goals)) return json.data.goals;
  return null;
}

export function validateAndNormalizeRecommendationsJson(json) {
  const goalsRaw = extractGoalsArray(json);
  if (!goalsRaw) return null;
  const goals = goalsRaw.map(sanitizeGoal).filter(Boolean);
  if (goals.length < 3) return null;
  // Enforce exactly 3 for the app spec by truncating extras.
  return { goals: goals.slice(0, 3) };
}

export async function generateWizardRecommendationsWithGemini({
  coreValueId,
  coreValueLabel,
  category,
  goalsPerCategory = 3,
  habitsPerGoal = 3,
}) {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const envModel = asNonEmptyString(process.env.GEMINI_MODEL);

  const instruction = [
    "You are generating goal + habit recommendations for a vision board app.",
    "Return ONLY valid JSON (no markdown, no code fences, no commentary).",
    "The JSON must match exactly this schema:",
    "{",
    '  "goals": [',
    "    {",
    '      "name": "string",',
    '      "whyImportant": "string",',
    '      "habits": [',
    "        {",
    '          "name": "string",',
    '          "frequency": "Daily" | "Weekly",',
    '          "cbtEnhancements": {',
    '            "microVersion": "string|null",',
    '            "predictedObstacle": "string|null",',
    '            "ifThenPlan": "string|null",',
    '            "confidenceScore": 0-10,',
    '            "reward": "string|null"',
    "          } | null",
    "        }",
    "      ]",
    "    }",
    "  ]",
    "}",
    "",
    `Constraints: goals.length MUST equal ${goalsPerCategory}.`,
    `Each goal should include around ${habitsPerGoal} habits.`,
    "Habits should be concrete, measurable, and realistic.",
    "For each habit, ALWAYS provide cbtEnhancements with non-empty microVersion and reward.",
  ].join("\n");

  const userPrompt = [
    `Core value: ${coreValueLabel || coreValueId}`,
    `Category: ${category}`,
    "",
    "Generate the recommendations now.",
  ].join("\n");

  // Model availability differs between accounts/regions and API versions.
  // We'll try a small set of common model ids unless explicitly configured.
  const modelCandidates = envModel
    ? [envModel]
    : [
        // Prefer "latest" aliases when available
        "gemini-1.5-flash-latest",
        "gemini-1.5-flash",
        "gemini-1.5-pro-latest",
        "gemini-1.5-pro",
        // Newer families (if enabled on the key)
        "gemini-2.0-flash",
        "gemini-2.0-flash-latest",
        "gemini-2.0-pro",
        "gemini-2.0-pro-latest",
      ];

  const apiVersions = ["v1beta", "v1"];

  async function callGeminiOnce({ temperature }) {
    const requestBody = {
      contents: [{ role: "user", parts: [{ text: `${instruction}\n\n${userPrompt}` }] }],
      generationConfig: {
        temperature,
        maxOutputTokens: 1400,
        responseMimeType: "application/json",
      },
    };

    let lastErr = null;
    let rawText = null;
    for (const apiVersion of apiVersions) {
      for (const model of modelCandidates) {
        const url = new URL(`https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent`);
        url.searchParams.set("key", apiKey);

        const max429Retries = Math.max(0, Math.min(5, Number(process.env.GEMINI_429_RETRIES ?? 3)));
        let attempt = 0;
        while (true) {
          const res = await fetch(url.toString(), {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(requestBody),
          });
          rawText = await res.text();
          if (res.status >= 200 && res.status < 300) {
            lastErr = null;
            break;
          }

          // Rate limit: wait and retry same model/version.
          if (res.status === 429 && attempt < max429Retries) {
            const delayMs = parseRetryDelayMs(rawText) ?? 12000; // free-tier is often ~5/min => ~12s
            attempt++;
            await sleepMs(delayMs);
            continue;
          }

          // Retry on "model not found / unsupported" style responses.
          if (res.status === 404 || res.status === 400) {
            lastErr = new Error(`Gemini generateContent failed (${res.status}) for ${apiVersion}/${model}: ${rawText}`);
            break; // try next model
          }

          // Other failures: don't spam retries; bubble up.
          throw new Error(`Gemini generateContent failed (${res.status}): ${rawText}`);
        }
        if (!lastErr) break;
      }
      if (!lastErr) break;
    }
    if (lastErr) throw lastErr;
    if (rawText == null) throw new Error("Gemini call failed without response body");
    return rawText;
  }

  // Some models occasionally omit fields; retry with lower temperature,
  // and as a last resort tighten the prompt.
  const attemptTemps = [0.6, 0.2];
  let lastValidationError = null;
  for (const t of attemptTemps) {
    const rawText = await callGeminiOnce({ temperature: t });

    let payload;
    try {
      payload = JSON.parse(rawText);
    } catch (e) {
      lastValidationError = new Error(`Gemini returned non-JSON: ${rawText.slice(0, 400)}`);
      continue;
    }

    const text =
      payload?.candidates?.[0]?.content?.parts?.map((p) => p?.text).filter(Boolean).join("") ??
      payload?.candidates?.[0]?.content?.parts?.[0]?.text ??
      null;

    // If responseMimeType works, API might already return JSON in parts[0].text.
    const jsonText = typeof text === "string" ? text.trim() : rawText.trim();
    let obj;
    try {
      obj = JSON.parse(jsonText);
    } catch (e) {
      // Some Gemini responses return the structured JSON directly (no nested text).
      obj = payload;
    }

    const validated = validateAndNormalizeRecommendationsJson(obj);
    if (validated) return validated;
    lastValidationError = new Error("Gemini response did not match expected recommendations schema (need >= 3 goals).");
  }

  // Last resort: ask again with stricter phrasing to force 3 items.
  async function callGeminiOnceWithPrompt({ temperature, promptText }) {
    const requestBody = {
      contents: [{ role: "user", parts: [{ text: promptText }] }],
      generationConfig: {
        temperature,
        maxOutputTokens: 1400,
        responseMimeType: "application/json",
      },
    };

    let lastErr = null;
    let rawText = null;
    for (const apiVersion of apiVersions) {
      for (const model of modelCandidates) {
        const url = new URL(`https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent`);
        url.searchParams.set("key", apiKey);

        const max429Retries = Math.max(0, Math.min(5, Number(process.env.GEMINI_429_RETRIES ?? 3)));
        let attempt = 0;
        while (true) {
          const res = await fetch(url.toString(), {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(requestBody),
          });
          rawText = await res.text();
          if (res.status >= 200 && res.status < 300) {
            lastErr = null;
            break;
          }

          if (res.status === 429 && attempt < max429Retries) {
            const delayMs = parseRetryDelayMs(rawText) ?? 12000;
            attempt++;
            await sleepMs(delayMs);
            continue;
          }

          if (res.status === 404 || res.status === 400) {
            lastErr = new Error(`Gemini generateContent failed (${res.status}) for ${apiVersion}/${model}: ${rawText}`);
            break;
          }

          throw new Error(`Gemini generateContent failed (${res.status}): ${rawText}`);
        }
        if (!lastErr) break;
      }
      if (!lastErr) break;
    }
    if (lastErr) throw lastErr;
    if (rawText == null) throw new Error("Gemini call failed without response body");
    return rawText;
  }

  const strictPromptText = [
    instruction,
    "",
    `IMPORTANT: Return EXACTLY ${goalsPerCategory} goals in a top-level "goals" array (no fewer).`,
    `If you are unsure, still return ${goalsPerCategory} plausible goals.`,
    "",
    userPrompt,
  ].join("\n");

  const strictRaw = await callGeminiOnceWithPrompt({ temperature: 0.1, promptText: strictPromptText });
  try {
    const payload = JSON.parse(strictRaw);
    const text =
      payload?.candidates?.[0]?.content?.parts?.map((p) => p?.text).filter(Boolean).join("") ??
      payload?.candidates?.[0]?.content?.parts?.[0]?.text ??
      null;
    const jsonText = typeof text === "string" ? text.trim() : strictRaw.trim();
    let obj;
    try {
      obj = JSON.parse(jsonText);
    } catch {
      obj = payload;
    }
    const validated = validateAndNormalizeRecommendationsJson(obj);
    if (validated) return validated;
  } catch (e) {
    // fall through
    lastValidationError = e;
  }

  throw lastValidationError ?? new Error("Gemini response invalid.");
}

function sanitizeCategoryBundle(entry) {
  if (!entry || typeof entry !== "object") return null;
  const category =
    asNonEmptyString(entry.category ?? entry.categoryLabel ?? entry.category_label ?? entry.name) ?? null;
  if (!category) return null;
  const goalsRaw = extractGoalsArray(entry);
  if (!goalsRaw) return null;
  const goals = goalsRaw.map(sanitizeGoal).filter(Boolean);
  if (goals.length < 3) return null;
  return { category, goals: goals.slice(0, 3) };
}

function extractCategoryBundles(json) {
  if (!json) return [];
  if (Array.isArray(json.categories)) return json.categories;
  if (Array.isArray(json.results)) return json.results;
  if (json.data && Array.isArray(json.data.categories)) return json.data.categories;
  const byCat = json.byCategory ?? json.by_category ?? null;
  if (byCat && typeof byCat === "object") {
    const out = [];
    for (const [k, v] of Object.entries(byCat)) {
      if (!v || typeof v !== "object") continue;
      out.push({ category: k, ...v });
    }
    return out;
  }
  return [];
}

export async function generateWizardRecommendationsBatchWithGemini({
  coreValueId,
  coreValueLabel,
  categories,
  goalsPerCategory = 3,
  habitsPerGoal = 3,
  maxCategoriesPerCall = 6,
}) {
  const apiKey = requireEnv("GEMINI_API_KEY");
  const envModel = asNonEmptyString(process.env.GEMINI_MODEL);

  const modelCandidates = envModel
    ? [envModel]
    : ["gemini-flash-latest", "gemini-pro-latest", "gemini-2.0-flash", "gemini-2.0-flash-001"];
  const apiVersions = ["v1beta", "v1"];

  const cats = Array.isArray(categories) ? categories.map((c) => String(c ?? "").trim()).filter(Boolean) : [];
  if (cats.isEmpty) return {};

  const chunks = [];
  for (let i = 0; i < cats.length; i += maxCategoriesPerCall) {
    chunks.push(cats.slice(i, i + maxCategoriesPerCall));
  }

  async function callGemini({ promptText, temperature }) {
    const requestBody = {
      contents: [{ role: "user", parts: [{ text: promptText }] }],
      generationConfig: { temperature, maxOutputTokens: 2400, responseMimeType: "application/json" },
    };

    let lastErr = null;
    let rawText = null;
    for (const apiVersion of apiVersions) {
      for (const model of modelCandidates) {
        const url = new URL(`https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent`);
        url.searchParams.set("key", apiKey);

        const max429Retries = Math.max(0, Math.min(5, Number(process.env.GEMINI_429_RETRIES ?? 3)));
        let attempt = 0;
        while (true) {
          const res = await fetch(url.toString(), {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(requestBody),
          });
          rawText = await res.text();
          if (res.status >= 200 && res.status < 300) {
            lastErr = null;
            break;
          }
          if (res.status === 429 && attempt < max429Retries) {
            const delayMs = parseRetryDelayMs(rawText) ?? 12000;
            attempt++;
            await sleepMs(delayMs);
            continue;
          }
          if (res.status === 404 || res.status === 400) {
            lastErr = new Error(`Gemini generateContent failed (${res.status}) for ${apiVersion}/${model}: ${rawText}`);
            break;
          }
          throw new Error(`Gemini generateContent failed (${res.status}): ${rawText}`);
        }
        if (!lastErr) break;
      }
      if (!lastErr) break;
    }
    if (lastErr) throw lastErr;
    if (rawText == null) throw new Error("Gemini call failed without response body");
    return rawText;
  }

  const result = {};
  for (const chunk of chunks) {
    const instruction = [
      "You are generating goal + habit recommendations for a vision board app.",
      "Return ONLY valid JSON (no markdown, no code fences, no commentary).",
      "Return a JSON object with this top-level schema:",
      '{ "categories": [ { "category": "string", "goals": [ ... ] } ] }',
      "",
      `Constraints: For EACH category, goals.length MUST equal ${goalsPerCategory}.`,
      `Each goal should include around ${habitsPerGoal} habits.`,
      "Each habit MUST include cbtEnhancements with non-empty microVersion and reward.",
    ].join("\n");

    const userPrompt = [
      `Core value: ${coreValueLabel || coreValueId}`,
      "Categories:",
      ...chunk.map((c) => `- ${c}`),
      "",
      "Generate the recommendations now.",
    ].join("\n");

    const promptText = `${instruction}\n\n${userPrompt}`;

    let parsed = null;
    let lastErr = null;
    for (const t of [0.4, 0.15]) {
      try {
        const rawText = await callGemini({ promptText, temperature: t });
        const payload = JSON.parse(rawText);
        const text =
          payload?.candidates?.[0]?.content?.parts?.map((p) => p?.text).filter(Boolean).join("") ??
          payload?.candidates?.[0]?.content?.parts?.[0]?.text ??
          null;
        const jsonText = typeof text === "string" ? text.trim() : rawText.trim();
        let obj;
        try {
          obj = JSON.parse(jsonText);
        } catch {
          obj = payload;
        }
        parsed = obj;
        break;
      } catch (e) {
        lastErr = e;
      }
    }
    if (!parsed) throw lastErr ?? new Error("Gemini batch response invalid.");

    const bundles = extractCategoryBundles(parsed).map(sanitizeCategoryBundle).filter(Boolean);
    for (const b of bundles) {
      const key = String(b.category).trim();
      if (!key) continue;
      result[key] = { goals: b.goals };
    }
  }

  return result;
}
