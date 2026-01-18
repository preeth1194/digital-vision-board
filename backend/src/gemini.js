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
  const model = asNonEmptyString(process.env.GEMINI_MODEL) ?? "gemini-1.5-flash";

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

  const url = new URL(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`);
  url.searchParams.set("key", apiKey);

  const res = await fetch(url.toString(), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: `${instruction}\n\n${userPrompt}` }] }],
      generationConfig: {
        temperature: 0.6,
        maxOutputTokens: 1200,
        responseMimeType: "application/json",
      },
    }),
  });
  const rawText = await res.text();
  if (res.status < 200 || res.status >= 300) {
    throw new Error(`Gemini generateContent failed (${res.status}): ${rawText}`);
  }

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

