## Digital Vision Board backend (Canva Connect)

This backend is a minimal service that:

- completes **Canva OAuth (PKCE)** and stores tokens per Canva user
- stores **synced board packages** (element→habit mappings, plus exported assets later)

### Setup

1) Install deps:

```bash
cd backend
npm install
```

2) Set environment variables (example):

- `PORT=8787`
- `BASE_URL=http://localhost:8787`
- `CANVA_CLIENT_ID=...`
- `CANVA_CLIENT_SECRET=...`
- `CANVA_REDIRECT_URI=http://localhost:8787/auth/canva/callback`
- `CANVA_SCOPES=design:content:read profile:read`

3) Run:

```bash
cd backend
npm run dev
```

### Notes

- Data is stored in `backend/data/` (JSON files).
- For local development, the OAuth callback page will `postMessage` a `dvToken` back to the opener window.

