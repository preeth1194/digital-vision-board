# Environment Variables Setup Guide

This document lists all environment variables needed for the Digital Vision Board project.

## Backend Environment Variables

Create a `.env` file in the `backend/` directory with the following variables:

### Required Variables

#### Core Configuration
- `PORT` - Server port (default: `8787`)
- `BASE_URL` - Base URL of the backend (e.g., `http://127.0.0.1:8787` or `http://localhost:8787`)

#### Canva OAuth Integration
- `CANVA_CLIENT_ID` - Your Canva Connect API client ID
- `CANVA_CLIENT_SECRET` - Your Canva Connect API client secret
- `CANVA_REDIRECT_URI` - OAuth callback URL (defaults to `${BASE_URL}/auth/canva/callback`)
  - For local dev, use: `http://127.0.0.1:8787/auth/canva/callback`
- `CANVA_SCOPES` - OAuth scopes (default: `design:content:read profile:read`)

### Optional Variables

#### Database (PostgreSQL)
- `DATABASE_URL` - PostgreSQL connection string (e.g., `postgres://user:password@localhost:5432/dbname`)
  - If not set, data is stored in JSON files in `backend/data/`
- `PGSSL` - Set to `"false"` to disable SSL (default: SSL enabled in production)
- `PG_POOL_MAX` - Maximum database connection pool size (default: `5`)

#### CORS
- `CORS_ORIGIN` - Allowed CORS origin (default: `"*"`)

#### Firebase Authentication (for Firebase auth exchange)
- `FIREBASE_SERVICE_ACCOUNT_JSON` - JSON string of Firebase service account credentials
  - Alternative: Use `GOOGLE_APPLICATION_CREDENTIALS` environment variable pointing to a file path

#### Gemini AI (for wizard recommendations)
- `GEMINI_API_KEY` - Required if using wizard recommendations feature
- `GEMINI_MODEL` - Gemini model name (optional, uses default if not set)
- `GEMINI_429_RETRIES` - Max retries for 429 rate limit errors (default: `3`)

#### Pexels API (for stock images)
- `PEXELS_API_KEY` - Required if using stock image search feature

#### Admin Configuration
- `DV_ADMIN_USER_IDS` - Comma-separated list of Canva user IDs with admin access
- `DV_ALLOW_DEV_ADMIN` - Set to `"true"` to allow all authenticated users admin access (dev only)

#### Wizard Sync Configuration
- `WIZARD_SYNC_ASYNC_DEFAULT` - Default to async mode for wizard sync (default: `"true"`)
- `WIZARD_BATCH_MAX_CATEGORIES` - Max categories per Gemini batch call (default: `6`)

#### Sync Retention
- `SYNC_RETAIN_DAYS` - Days to retain sync logs (default: `90`)

#### Node Environment
- `NODE_ENV` - Set to `"production"` for production environment

## Canva App Panel Environment Variables

The Canva app panel (in `canva-app-panel/`) can optionally use:

- `VITE_BACKEND_BASE_URL` - Backend URL (default: `http://localhost:8787`)

## Example `.env` File

Create `backend/.env`:

```env
# Core
PORT=8787
BASE_URL=http://127.0.0.1:8787

# Canva OAuth (required)
CANVA_CLIENT_ID=your_canva_client_id_here
CANVA_CLIENT_SECRET=your_canva_client_secret_here
CANVA_REDIRECT_URI=http://127.0.0.1:8787/auth/canva/callback
CANVA_SCOPES=design:content:read profile:read

# Database (optional - if not set, uses JSON file storage)
DATABASE_URL=postgres://user:password@localhost:5432/digital_vision_board

# Firebase (optional - for Firebase auth exchange)
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}

# Gemini AI (optional - for wizard recommendations)
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-1.5-flash

# Pexels (optional - for stock images)
PEXELS_API_KEY=your_pexels_api_key_here

# Admin (optional)
DV_ADMIN_USER_IDS=user_id_1,user_id_2
DV_ALLOW_DEV_ADMIN=false

# CORS (optional)
CORS_ORIGIN=*

# Node Environment
NODE_ENV=development
```

## Notes

1. **Local Development**: For local development, use `127.0.0.1` instead of `localhost` in URLs (Canva OAuth requirement).

2. **Database**: If `DATABASE_URL` is not set, the backend will use JSON file storage in `backend/data/`. This is fine for development but not recommended for production.

3. **Firebase**: Only needed if you're using Firebase authentication. The backend supports guest authentication without Firebase.

4. **Gemini & Pexels**: These are optional features. The app will work without them, but wizard recommendations and stock image search won't be available.

5. **Admin Access**: In development, you can set `DV_ALLOW_DEV_ADMIN=true` to bypass admin checks. Never use this in production.
