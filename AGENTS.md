# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Digital Vision Board is a gamified habit-tracking and vision board app with two services:
- **Flutter frontend** (root `/workspace`) — runs on web, Android, iOS, macOS, Windows
- **Node.js/Express backend** (`/workspace/backend`) — handles auth, templates, wizard recommendations, stock images

### Running services

**Backend** (port 8787):
```bash
cd backend
DATABASE_URL= BASE_URL=http://127.0.0.1:8787 PORT=8787 NODE_ENV=development npm run dev
```
The injected `DATABASE_URL` secret points to an unreachable remote Postgres host. You **must** unset it (`DATABASE_URL=`) when starting the backend locally, which makes it fall back to JSON file storage in `backend/data/`. This is sufficient for development and guest auth but some endpoints (templates, stock images, gift codes, encryption keys) return `501 database_required`.

**Flutter web** (port 3000):
```bash
flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0 \
  --dart-define=BACKEND_BASE_URL=http://localhost:8787
```
The `--dart-define=BACKEND_BASE_URL` flag is required to point the app at the local backend instead of the production Render URL.

### Lint / Test / Build

- **Lint**: `flutter analyze` — 0 errors expected; pre-existing warnings/info are normal
- **Test**: `flutter test` — runs widget tests in `test/`
- **Build web**: `flutter build web --dart-define=BACKEND_BASE_URL=http://localhost:8787`
- See `README.md` for CI/CD and platform-specific notes

### Key caveats

- Firebase initialization is wrapped in `try/catch` — the app runs fine without Firebase configured (guest mode only).
- The Flutter SDK must be on `PATH`. It is installed at `/home/ubuntu/flutter-sdk` and added to `~/.bashrc`.
- The backend uses ES Modules (`"type": "module"` in `package.json`); `npm run dev` uses `node --watch` for hot reload.
- `backend/.env` is gitignored; environment variables are set inline or via the `.env` file. The minimal required vars are `PORT`, `BASE_URL`, and `NODE_ENV`.
