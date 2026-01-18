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
  const name = asNonEmptyString(h.name);
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
  const name = asNonEmptyString(g.name);
  if (!name) return null;
  const whyImportant = asNonEmptyString(g.whyImportant ?? g.why_important) ?? "";
  const habitsRaw = Array.isArray(g.habits) ? g.habits : [];
  const habits = habitsRaw.map(sanitizeHabit).filter(Boolean);
  return { name, whyImportant, habits };
}

export function validateAndNormalizeRecommendationsJson(json) {
  const goalsRaw = Array.isArray(json?.goals) ? json.goals : null;
  if (!goalsRaw) return null;
  const goals = goalsRaw.map(sanitizeGoal).filter(Boolean);
  if (goals.length !== 3) return null; // strict per spec
  return { goals };
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

  const requestBody = {
    contents: [{ role: "user", parts: [{ text: `${instruction}\n\n${userPrompt}` }] }],
    generationConfig: {
      temperature: 0.6,
      maxOutputTokens: 1200,
      responseMimeType: "application/json",
    },
  };

  let lastErr = null;
  let rawText = null;
  for (const apiVersion of apiVersions) {
    for (const model of modelCandidates) {
      const url = new URL(`https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent`);
      url.searchParams.set("key", apiKey);

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

      // Retry on "model not found / unsupported" style responses.
      if (res.status === 404 || res.status === 400) {
        lastErr = new Error(`Gemini generateContent failed (${res.status}) for ${apiVersion}/${model}: ${rawText}`);
        continue;
      }

      // Other failures: don't spam retries; bubble up.
      throw new Error(`Gemini generateContent failed (${res.status}): ${rawText}`);
    }
    if (!lastErr) break;
  }
  if (lastErr) throw lastErr;
  if (rawText == null) throw new Error("Gemini call failed without response body");

  let payload;
  try {
    payload = JSON.parse(rawText);
  } catch (e) {
    throw new Error(`Gemini returned non-JSON: ${rawText.slice(0, 400)}`);
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
  if (!validated) {
    throw new Error("Gemini response did not match expected recommendations schema (need exactly 3 goals).");
  }
  return validated;
}

