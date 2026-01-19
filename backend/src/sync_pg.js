import { withClient } from "./db.js";

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isLogicalDate(v) {
  return typeof v === "string" && DATE_RE.test(v);
}

export async function getUserSettingsPg(canvaUserId) {
  return await withClient(async (c) => {
    const r = await c.query("select home_timezone, gender from dv_user_settings where canva_user_id = $1", [canvaUserId]);
    if (!r.rowCount) return { homeTimezone: null, gender: "prefer_not_to_say" };
    return {
      homeTimezone: r.rows[0].home_timezone ?? null,
      gender: r.rows[0].gender ?? "prefer_not_to_say",
    };
  });
}

export async function putUserSettingsPg(canvaUserId, { homeTimezone, gender }) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_user_settings (canva_user_id, home_timezone, gender)
       values ($1, $2, $3)
       on conflict (canva_user_id) do update set
         home_timezone = excluded.home_timezone,
         gender = excluded.gender,
         updated_at = now()`,
      [canvaUserId, homeTimezone ?? null, gender ?? "prefer_not_to_say"],
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
        await c.query(
          `insert into dv_user_settings (canva_user_id, home_timezone, gender)
           values ($1, $2, $3)
           on conflict (canva_user_id) do update set
             home_timezone = excluded.home_timezone,
             gender = excluded.gender,
             updated_at = now()`,
          [canvaUserId, tz, gender],
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

