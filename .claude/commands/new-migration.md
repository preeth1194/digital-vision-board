# New SQL Migration Skill

Create a new PostgreSQL migration file for the Digital Vision Board backend.

## Instructions

### 1. Naming Convention

Migrations live in `backend/src/migrations/` and follow strict sequential numbering:

```
NNN_description.sql
```

- `NNN` = next number after the highest existing migration (currently up to `020`)
- `description` = lowercase, underscores, brief description of what it does
- Example: `021_habit_streaks.sql`

**NEVER edit existing migration files.** Migrations are append-only.

### 2. Find the Next Number

Before creating, check the highest existing number:
```bash
ls backend/src/migrations/ | sort | tail -5
```

### 3. Migration File Template

```sql
-- Migration: NNN_description
-- Purpose: [one-line description of what this changes and why]
-- Created: YYYY-MM-DD

-- Up migration (idempotent where possible)

CREATE TABLE IF NOT EXISTS my_table (
  id          BIGSERIAL PRIMARY KEY,
  user_id     TEXT NOT NULL,
  data        JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_my_table_user_id ON my_table(user_id);

-- If adding a column to an existing table:
-- ALTER TABLE existing_table ADD COLUMN IF NOT EXISTS new_col TEXT;
```

### 4. Rules

| Rule | Detail |
|---|---|
| **Idempotent** | Use `IF NOT EXISTS` / `IF EXISTS` — migrations may be re-run |
| **No destructive ops without comment** | `DROP`, `DELETE`, `TRUNCATE` need a clear reason comment |
| **Index foreign-key columns** | Always add `CREATE INDEX IF NOT EXISTS` for user_id and FK columns |
| **Timestamps** | Include `created_at` and `updated_at TIMESTAMPTZ DEFAULT NOW()` on new tables |
| **user_id type** | Use `TEXT` (Firebase UID or DV guest ID) — not integer FK |
| **JSONB for flexible data** | Prefer `JSONB` over many individual columns for user-defined content |
| **No raw passwords** | Never store passwords; auth is handled by Firebase or DV token system |

### 5. Run the Migration

After creating the file:
```bash
cd backend
node src/migrate.js
```

### 6. Update Storage Modules

After the migration, update the corresponding storage module(s) to use the new table/column:
- `backend/src/storage_pg.js` — user data storage
- Or the relevant `*_pg.js` module for the feature

Also update `backend/src/storage.js` (JSON fallback) with an equivalent in-memory implementation so the app works without PostgreSQL.

---

## Task

Create the SQL migration described in `$ARGUMENTS`.

- List the next migration number (check existing files first)
- Write the complete `.sql` file content
- Note which `*_pg.js` and `storage.js` methods need to be added/updated
- Confirm the migration is idempotent
