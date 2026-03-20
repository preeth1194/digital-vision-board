# Backend Route Skill

Add a new Express API route to the Digital Vision Board Node.js backend.

## Instructions

### 1. File Location

All routes are defined in `backend/src/server.js`. Storage logic lives in dedicated modules:

| Concern | File |
|---|---|
| User data (boards, habits, journal) | `backend/src/storage_pg.js` (PostgreSQL) / `backend/src/storage.js` (JSON) |
| Sync / encryption keys | `backend/src/sync_pg.js` |
| Templates | `backend/src/templates_pg.js` |
| Affirmations | `backend/src/affirmations_pg.js` |
| Gift codes | `backend/src/gift_codes_pg.js` |
| Contact / support | `backend/src/contact_pg.js` |
| Stock category images | `backend/src/stock_category_images_pg.js` |
| Wizard AI | `backend/src/gemini.js` + `backend/src/wizard_storage_pg.js` |
| Stock photos (Pexels) | `backend/src/pexels.js` |

### 2. Route Structure Pattern

```javascript
// Auth-protected route
app.get('/api/my-feature', async (req, res) => {
  try {
    const userId = await getUserId(req); // from backend/src/auth.js
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const data = await db.myFeatureGet(userId);
    res.json(data);
  } catch (err) {
    console.error('GET /api/my-feature error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mutation route
app.post('/api/my-feature', async (req, res) => {
  try {
    const userId = await getUserId(req);
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { field1, field2 } = req.body;
    if (!field1) return res.status(400).json({ error: 'field1 required' });

    const result = await db.myFeatureSave(userId, { field1, field2 });
    res.json(result);
  } catch (err) {
    console.error('POST /api/my-feature error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

### 3. Authentication

Always authenticate using `getUserId(req)` from `backend/src/auth.js`:
```javascript
const { getUserId } = require('./auth');
// Already imported at the top of server.js — do not re-import
```

Returns `null` for unauthenticated requests. Always return `401` if null.

### 4. Database Abstraction

Use `db.*` methods from `backend/src/db.js` — never query PostgreSQL directly in `server.js`:
```javascript
const db = require('./db');
// db.* methods abstract both PostgreSQL and JSON-file storage
```

If adding new storage methods, add them to **both** `storage.js` (JSON fallback) and `storage_pg.js` (PostgreSQL), maintaining the same function signature.

### 5. SQL Migrations

If your route requires a new table or column:
1. Create `backend/src/migrations/NNN_description.sql` (next sequential number)
2. Never edit existing migration files
3. Migration runs via `node src/migrate.js`

### 6. Input Validation

- Validate all `req.body` and `req.params` fields
- Return `400` with a descriptive `{ error: '...' }` for missing/invalid input
- Sanitise strings — never pass user input directly to SQL (use parameterised queries)

### 7. Admin vs User Routes

Admin routes should check for admin status before proceeding:
```javascript
const isAdmin = await checkIsAdmin(userId); // implement in auth.js if needed
if (!isAdmin) return res.status(403).json({ error: 'Forbidden' });
```

### 8. CORS & Middleware

Already configured globally — do not add per-route CORS headers.

### 9. Error Logging

Always log errors with context:
```javascript
console.error('METHOD /api/route-name error:', err);
```

---

## Task

Create the backend route(s) described in `$ARGUMENTS`.

- Identify the correct file(s) to modify
- Write complete JavaScript code
- List any new database methods needed and their signatures
- Note any SQL migration required
- Do not break existing routes
