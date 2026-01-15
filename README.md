# Digital Vision Board (Flutter)

A digital vision board app with **freeform canvas** and **grid** board templates, plus **habit tracking** and **insights**.

## Canva integration (Option B: templates → layered habit mapping)

This repo includes an end-to-end **Canva template import workflow**:

- **In Canva**: the user searches Canva templates in Canva’s UI, opens a design, then uses the **Digital Vision Board Canva panel** to:
  - connect to your backend (OAuth)
  - select elements and **attach a habit** to each
  - sync the mapping to the backend
- **Backend**: stores the sync “package” and can **export the design** to PNG using Canva Connect `/exports`
- **In Flutter**: an **Import from Canva** button pulls the latest package, sets the exported PNG as the board background, and creates `ZoneComponent`s with associated `HabitItem`s.

### Current limitations

- Canva does not provide a public API to browse/search the entire template library externally; users search templates inside Canva.
- True “pixel-perfect per-layer import” of arbitrary Canva elements is not guaranteed; this v1 preserves **habit associations** via zones and uses the **exported PNG** as background.
- **Web**: Canva import and some file-path based image flows are not supported.

## Features

### Vision boards (Dashboard)
- **Create multiple boards** with a title, icon, tile color, and template:
  - **Freeform canvas**
  - **Grid layout**
- **Edit or view** a board from the dashboard
- **Delete boards** (also deletes that board’s stored data)

### Freeform canvas board
- **Edit / View modes**
  - Edit mode: build and arrange your board
  - View mode: browse board + open habit tracking for components
- **Background**
  - Set a **solid background color**
  - **Upload a background image** (native platforms)
  - **Clear background image**
- **Add content**
  - **Text components** with live preview + formatting controls
    - Font size, weight, alignment, and color
  - **Image components** from device gallery (native platforms)
- **Manipulate components**
  - Drag/move, resize (handles), rotate, scale
  - **Layer management**: reorder layers and update z-index
- **Legacy hotspot migration**
  - Converts older “hotspot” records into zone components when loading a board image

### Grid layout board
- **Staggered grid** layout
- **Add tiles**
  - Text tiles (create + edit)
  - Image tiles (pick + crop)
- **Resize mode** to adjust tile width/height (within constraints)
- **Delete tiles**
- Tiles are **stored and restored** per board

### Habits
- **Habits per component** (each zone/text/image component maintains its own habit list)
- **Habit Tracker bottom sheet**
  - Add/delete habits
  - Toggle completion for today
  - Calendar view (monthly markers)
  - “Last 7 days” bar chart
- **Habits tab**
  - If a board is selected: shows habits for that board
  - Otherwise: shows an aggregated “all boards habits” view

### Insights
- **Insights tab**
  - If a board is selected: insights for that board
  - Otherwise: overall insights across all boards
- Global insights include:
  - Today’s completion rate
  - Last 7 days activity chart
  - Summary stats (zones, habits, longest streak)

## Data & persistence
- Uses **SharedPreferences** to persist:
  - Board list + active board selection
  - Freeform components + background color
  - Background image path (native platforms)
  - Grid tiles per board

## Platform notes
- **Web**: image pick/crop flows are currently limited in this app (cropping + some file-path based flows are not supported).

## Setup: Backend (Canva Connect)

The backend lives in `backend/` and provides OAuth + storage + export endpoints.

### 1) Canva Developer settings

Create a **Canva Connect API integration** and configure:

- **Authorized redirect URL**: must use `127.0.0.1` (not `localhost`) for local dev, e.g.
  - `http://127.0.0.1:8787/auth/canva/callback`
- **Scopes** (minimum):
  - `design:content:read`
  - `profile:read` (recommended)

### 2) Backend environment variables

Create `backend/.env`:

```env
PORT=8787
BASE_URL=http://127.0.0.1:8787
CANVA_REDIRECT_URI=http://127.0.0.1:8787/auth/canva/callback
CANVA_CLIENT_ID=...
CANVA_CLIENT_SECRET=...
CANVA_SCOPES=design:content:read profile:read
```

### 3) Run the backend

```bash
cd backend
npm install
npm run dev
```

Useful endpoints:

- `GET /health`
- `GET /auth/canva/start?origin=http://127.0.0.1:8787` (OAuth in a popup and `postMessage` back)
- `GET /canva/connect` (alias used by the Canva panel)
- Authenticated (requires `Authorization: Bearer <dvToken>`):
  - `GET /habits`
  - `POST /habits`
  - `POST /canva/sync`
  - `POST /canva/export`
  - `GET /canva/packages/latest`

## Setup: Canva App Panel (runs inside Canva)

The Canva panel lives in `canva-app-panel/`.

```bash
cd canva-app-panel
npm install
npm run dev
```

Configure backend URL (optional):

- Set `VITE_BACKEND_BASE_URL` (defaults to `http://localhost:8787`)

In the Canva panel:

1. Click **Connect to Digital Vision Board** (stores a `dvToken`)
2. Click **Load habits**
3. Select an element in Canva → **Attach habit to selection**
4. Click **Sync board to app**

This creates a stored “package” on the backend containing element selections, bounds (when available), and habit mappings. The backend can then export the design as a PNG.

## Setup: Flutter “Import from Canva”

In the freeform editor (`VisionBoardEditorScreen`), the bottom bar includes:

- **Import from Canva** (cloud-download icon)

On first run it opens OAuth in the browser and expects a deep-link return to:

- `dvb://oauth?dvToken=...`

Platform setup included:

- Android intent-filter for scheme `dvb` / host `oauth`
- iOS URL scheme `dvb`

The import flow:

1. Fetches latest package from backend
2. Downloads exported PNG (if present) and stores it as board background
3. Creates `ZoneComponent`s for mapped bounds and attaches the chosen `HabitItem` to each

