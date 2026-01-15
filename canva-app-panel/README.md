# Canva App Panel – Digital Vision Board

This is the **Canva App panel** (web) that lets a user:
- load habits from your backend
- attach a habit to the user’s current Canva selection
- trigger a sync call to your backend

## Configure

Set a backend base URL via Vite env:

- `VITE_BACKEND_BASE_URL` (default: `http://localhost:8787`)

Your backend is expected to expose:
- `GET /habits` → JSON array of habits (at minimum `{ id, name }`)
- `POST /canva/sync` → accepts the sync payload
- `GET /canva/connect` → starts the OAuth/connect flow (opens in a new tab)

## Run locally

```bash
cd canva-app-panel
npm install
npm run dev
```

## Notes / limitations (current)

- Canva’s Selection API doesn’t reliably expose **element geometry + IDs** for all selection types. This panel stores mappings keyed off a best-effort “selection key” (refs/text hashes) and includes optional “Try enrich with geometry” output when available.

