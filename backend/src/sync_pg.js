import { withClient } from "./db.js";

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isLogicalDate(v) {
  return typeof v === "string" && DATE_RE.test(v);
}

export async function getUserSettingsPg(canvaUserId) {
  return await withClient(async (c) => {
    const r = await c.query(
      "select home_timezone, gender, display_name, weight_kg, height_cm, date_of_birth, subscription_plan_id, subscription_active, subscription_updated_at, encryption_key from dv_user_settings where canva_user_id = $1",
      [canvaUserId]
    );
    if (!r.rowCount) return { homeTimezone: null, gender: "prefer_not_to_say", displayName: null, weightKg: null, heightCm: null, dateOfBirth: null, subscriptionPlanId: null, subscriptionActive: false, subscriptionUpdatedAt: null, encryptionKey: null };
    const row = r.rows[0];
    const dob = row.date_of_birth;
    return {
      homeTimezone: row.home_timezone ?? null,
      gender: row.gender ?? "prefer_not_to_say",
      displayName: row.display_name ?? null,
      weightKg: row.weight_kg != null ? Number(row.weight_kg) : null,
      heightCm: row.height_cm != null ? Number(row.height_cm) : null,
      dateOfBirth: dob != null ? (typeof dob === "string" ? dob : dob.toISOString?.().slice(0, 10)) : null,
      subscriptionPlanId: row.subscription_plan_id ?? null,
      subscriptionActive: Boolean(row.subscription_active),
      subscriptionUpdatedAt: row.subscription_updated_at?.toISOString?.() ?? row.subscription_updated_at ?? null,
      encryptionKey: row.encryption_key ?? null,
    };
  });
}

export async function getEncryptionKeyPg(canvaUserId) {
  return await withClient(async (c) => {
    const r = await c.query(
      "select encryption_key from dv_user_settings where canva_user_id = $1",
      [canvaUserId]
    );
    return r.rowCount ? (r.rows[0].encryption_key ?? null) : null;
  });
}

export async function putEncryptionKeyPg(canvaUserId, encryptionKey) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_user_settings (canva_user_id, encryption_key)
       values ($1, $2)
       on conflict (canva_user_id) do update set
         encryption_key = coalesce(dv_user_settings.encryption_key, excluded.encryption_key),
         updated_at = now()`,
      [canvaUserId, encryptionKey]
    );
  });
}

export async function putUserSettingsPg(canvaUserId, { homeTimezone, gender, displayName, weightKg, heightCm, dateOfBirth, subscriptionPlanId, subscriptionActive }) {
  return await withClient(async (c) => {
    const dobVal = dateOfBirth && typeof dateOfBirth === "string" && /^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth) ? dateOfBirth : null;
    const subActive = subscriptionActive != null ? Boolean(subscriptionActive) : null;
    const subPlan = typeof subscriptionPlanId === "string" && subscriptionPlanId.trim() ? subscriptionPlanId.trim() : null;
    await c.query(
      `insert into dv_user_settings (canva_user_id, home_timezone, gender, display_name, weight_kg, height_cm, date_of_birth, subscription_plan_id, subscription_active, subscription_updated_at)
       values ($1, $2, $3, $4, $5, $6, $7::date, $8, coalesce($9, false), case when $9 is not null then now() else null end)
       on conflict (canva_user_id) do update set
         home_timezone = coalesce(excluded.home_timezone, dv_user_settings.home_timezone),
         gender = coalesce(excluded.gender, dv_user_settings.gender),
         display_name = coalesce(excluded.display_name, dv_user_settings.display_name),
         weight_kg = coalesce(excluded.weight_kg, dv_user_settings.weight_kg),
         height_cm = coalesce(excluded.height_cm, dv_user_settings.height_cm),
         date_of_birth = coalesce(excluded.date_of_birth, dv_user_settings.date_of_birth),
         subscription_plan_id = coalesce(excluded.subscription_plan_id, dv_user_settings.subscription_plan_id),
         subscription_active = case when $9 is not null then excluded.subscription_active else dv_user_settings.subscription_active end,
         subscription_updated_at = case when $9 is not null then now() else dv_user_settings.subscription_updated_at end,
         updated_at = now()`,
      [canvaUserId, homeTimezone ?? null, gender ?? "prefer_not_to_say", displayName ?? null, weightKg ?? null, heightCm ?? null, dobVal ?? null, subPlan, subActive],
    );
  });
}

export async function listBoardsPg(canvaUserId) {
  return await withClient(async (c) => {
    const r = await c.query(
      "select board_id, board_json, updated_at from dv_boards where canva_user_id = $1 order by updated_at desc",
      [canvaUserId],
    );
    return r.rows.map((row) => ({
      boardId: row.board_id,
      boardJson: row.board_json,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    }));
  });
}

export async function upsertBoardPg(canvaUserId, { boardId, boardJson }) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_boards (canva_user_id, board_id, board_json)
       values ($1, $2, $3::jsonb)
       on conflict (canva_user_id, board_id) do update set
         board_json = excluded.board_json,
         updated_at = now()`,
      [canvaUserId, boardId, JSON.stringify(boardJson ?? {})],
    );
  });
}

export async function getRecentHabitCompletionsPg(canvaUserId, days) {
  return await withClient(async (c) => {
    const r = await c.query(
      `select board_id, component_id, habit_id, logical_date::text as logical_date, rating, note, updated_at
       from dv_habit_completions
       where canva_user_id = $1
         and logical_date >= (current_date - $2::int)
       order by logical_date desc, updated_at desc`,
      [canvaUserId, days],
    );
    return r.rows.map((row) => ({
      boardId: row.board_id,
      componentId: row.component_id,
      habitId: row.habit_id,
      logicalDate: row.logical_date,
      rating: row.rating ?? null,
      note: row.note ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    }));
  });
}

export async function getRecentChecklistEventsPg(canvaUserId, days) {
  return await withClient(async (c) => {
    const r = await c.query(
      `select board_id, component_id, task_id, item_id, logical_date::text as logical_date, rating, note, updated_at
       from dv_checklist_events
       where canva_user_id = $1
         and logical_date >= (current_date - $2::int)
       order by logical_date desc, updated_at desc`,
      [canvaUserId, days],
    );
    return r.rows.map((row) => ({
      boardId: row.board_id,
      componentId: row.component_id,
      taskId: row.task_id,
      itemId: row.item_id,
      logicalDate: row.logical_date,
      rating: row.rating ?? null,
      note: row.note ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    }));
  });
}

export async function applySyncPushPg(canvaUserId, { boards, userSettings, habitCompletions, checklistEvents, retainDays }) {
  return await withClient(async (c) => {
    await c.query("begin");
    try {
      if (userSettings && typeof userSettings === "object") {
        const tz = typeof userSettings.homeTimezone === "string" ? userSettings.homeTimezone : null;
        const gender =
          typeof userSettings.gender === "string" && userSettings.gender.trim()
            ? userSettings.gender.trim()
            : "prefer_not_to_say";
        const displayName = typeof userSettings.displayName === "string" ? userSettings.displayName : null;
        const weightKg = typeof userSettings.weightKg === "number" ? userSettings.weightKg : null;
        const heightCm = typeof userSettings.heightCm === "number" ? userSettings.heightCm : null;
        const dob = userSettings.dateOfBirth && typeof userSettings.dateOfBirth === "string" && /^\d{4}-\d{2}-\d{2}$/.test(userSettings.dateOfBirth) ? userSettings.dateOfBirth : null;
        const subActive = userSettings.subscriptionActive != null ? Boolean(userSettings.subscriptionActive) : null;
        const subPlan = typeof userSettings.subscriptionPlanId === "string" && userSettings.subscriptionPlanId.trim() ? userSettings.subscriptionPlanId.trim() : null;
        await c.query(
          `insert into dv_user_settings (canva_user_id, home_timezone, gender, display_name, weight_kg, height_cm, date_of_birth, subscription_plan_id, subscription_active, subscription_updated_at)
           values ($1, $2, $3, $4, $5, $6, $7::date, $8, coalesce($9, false), case when $9 is not null then now() else null end)
           on conflict (canva_user_id) do update set
             home_timezone = coalesce(excluded.home_timezone, dv_user_settings.home_timezone),
             gender = coalesce(excluded.gender, dv_user_settings.gender),
             display_name = coalesce(excluded.display_name, dv_user_settings.display_name),
             weight_kg = coalesce(excluded.weight_kg, dv_user_settings.weight_kg),
             height_cm = coalesce(excluded.height_cm, dv_user_settings.height_cm),
             date_of_birth = coalesce(excluded.date_of_birth, dv_user_settings.date_of_birth),
             subscription_plan_id = coalesce(excluded.subscription_plan_id, dv_user_settings.subscription_plan_id),
             subscription_active = case when $9 is not null then excluded.subscription_active else dv_user_settings.subscription_active end,
             subscription_updated_at = case when $9 is not null then now() else dv_user_settings.subscription_updated_at end,
             updated_at = now()`,
          [canvaUserId, tz, gender, displayName, weightKg, heightCm, dob, subPlan, subActive],
        );
      }

      if (Array.isArray(boards)) {
        for (const b of boards) {
          const boardId = typeof b?.boardId === "string" ? b.boardId : null;
          if (!boardId) continue;
          await c.query(
            `insert into dv_boards (canva_user_id, board_id, board_json)
             values ($1, $2, $3::jsonb)
             on conflict (canva_user_id, board_id) do update set
               board_json = excluded.board_json,
               updated_at = now()`,
            [canvaUserId, boardId, JSON.stringify(b?.boardJson ?? {})],
          );
        }
      }

      if (Array.isArray(habitCompletions)) {
        for (const h of habitCompletions) {
          const boardId = typeof h?.boardId === "string" ? h.boardId : null;
          const componentId = typeof h?.componentId === "string" ? h.componentId : null;
          const habitId = typeof h?.habitId === "string" ? h.habitId : null;
          const logicalDate = typeof h?.logicalDate === "string" ? h.logicalDate : null;
          if (!boardId || !componentId || !habitId || !isLogicalDate(logicalDate)) continue;

          const deleted = Boolean(h?.deleted);
          if (deleted) {
            await c.query(
              `delete from dv_habit_completions
               where canva_user_id = $1 and board_id = $2 and component_id = $3 and habit_id = $4 and logical_date = $5::date`,
              [canvaUserId, boardId, componentId, habitId, logicalDate],
            );
            continue;
          }

          const rating = typeof h?.rating === "number" ? h.rating : null;
          const note = typeof h?.note === "string" ? h.note : null;
          await c.query(
            `insert into dv_habit_completions (
               canva_user_id, board_id, component_id, habit_id, logical_date, rating, note
             ) values ($1,$2,$3,$4,$5::date,$6,$7)
             on conflict (canva_user_id, board_id, component_id, habit_id, logical_date) do update set
               rating = excluded.rating,
               note = excluded.note,
               updated_at = now()`,
            [canvaUserId, boardId, componentId, habitId, logicalDate, rating, note],
          );
        }
      }

      if (Array.isArray(checklistEvents)) {
        for (const e of checklistEvents) {
          const boardId = typeof e?.boardId === "string" ? e.boardId : null;
          const componentId = typeof e?.componentId === "string" ? e.componentId : null;
          const taskId = typeof e?.taskId === "string" ? e.taskId : null;
          const itemId = typeof e?.itemId === "string" ? e.itemId : null;
          const logicalDate = typeof e?.logicalDate === "string" ? e.logicalDate : null;
          if (!boardId || !componentId || !taskId || !itemId || !isLogicalDate(logicalDate)) continue;

          const deleted = Boolean(e?.deleted);
          if (deleted) {
            await c.query(
              `delete from dv_checklist_events
               where canva_user_id = $1 and board_id = $2 and component_id = $3 and task_id = $4 and item_id = $5 and logical_date = $6::date`,
              [canvaUserId, boardId, componentId, taskId, itemId, logicalDate],
            );
            continue;
          }

          const rating = typeof e?.rating === "number" ? e.rating : null;
          const note = typeof e?.note === "string" ? e.note : null;
          await c.query(
            `insert into dv_checklist_events (
               canva_user_id, board_id, component_id, task_id, item_id, logical_date, rating, note
             ) values ($1,$2,$3,$4,$5,$6::date,$7,$8)
             on conflict (canva_user_id, board_id, component_id, task_id, item_id, logical_date) do update set
               rating = excluded.rating,
               note = excluded.note,
               updated_at = now()`,
            [canvaUserId, boardId, componentId, taskId, itemId, logicalDate, rating, note],
          );
        }
      }

      if (typeof retainDays === "number" && Number.isFinite(retainDays) && retainDays > 0) {
        await c.query(
          "delete from dv_habit_completions where canva_user_id = $1 and logical_date < (current_date - $2::int)",
          [canvaUserId, retainDays],
        );
        await c.query(
          "delete from dv_checklist_events where canva_user_id = $1 and logical_date < (current_date - $2::int)",
          [canvaUserId, retainDays],
        );
      }

      await c.query("commit");
      return { ok: true };
    } catch (e) {
      await c.query("rollback");
      throw e;
    }
  });
}

export async function cleanupOldLogsPg(canvaUserId, retainDays) {
  if (typeof retainDays !== "number" || !Number.isFinite(retainDays) || retainDays <= 0) return;
  return await withClient(async (c) => {
    await c.query("delete from dv_habit_completions where canva_user_id = $1 and logical_date < (current_date - $2::int)", [
      canvaUserId,
      retainDays,
    ]);
    await c.query("delete from dv_checklist_events where canva_user_id = $1 and logical_date < (current_date - $2::int)", [
      canvaUserId,
      retainDays,
    ]);
  });
}

