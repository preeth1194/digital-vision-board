## Digital Vision Board backend

This backend is a minimal service that:

- handles **authentication** (Firebase, guest sessions)
- stores **user settings** and **board data**
- serves **templates** and **stock images**
- generates **wizard recommendations** via Gemini AI

### Setup

1) Install deps:

```bash
cd backend
npm install
```

2) Set environment variables (example):

- `PORT=8787`
- `BASE_URL=http://localhost:8787`
- `DATABASE_URL=postgres://...` (optional; enables Postgres storage)
- `FIREBASE_SERVICE_ACCOUNT_JSON=...` (optional; for Firebase auth)
- `GEMINI_API_KEY=...` (optional; for wizard recommendations)
- `PEXELS_API_KEY=...` (optional; for stock images)

3) Run:

```bash
cd backend
npm run dev
```

### Notes

- If `DATABASE_URL` is set, data is stored in Postgres. Otherwise data is stored in `backend/data/` (JSON files).
- See `ENV_SETUP.md` in the project root for the full environment variable reference.

### Postgres schema

Run the SQL in:

- `backend/sql/001_init.sql`
