import { withClient } from "./db.js";

export async function insertContactMessagePg({ name, email, message }) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_contact_messages (name, email, message)
       values ($1, $2, $3)`,
      [name, email, message],
    );
    return { ok: true };
  });
}
