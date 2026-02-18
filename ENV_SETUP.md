# Environment Variables Setup Guide

This document lists all environment variables needed for the Digital Vision Board project.

## Backend Environment Variables

Create a `.env` file in the `backend/` directory with the following variables:

### Required Variables

#### Core Configuration
- `PORT` - Server port (default: `8787`)
- `BASE_URL` - Base URL of the backend (e.g., `http://127.0.0.1:8787` or `http://localhost:8787`)

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

#### Wizard Sync Configuration
- `WIZARD_BATCH_MAX_CATEGORIES` - Max categories per Gemini batch call (default: `6`)

#### Sync Retention
- `SYNC_RETAIN_DAYS` - Days to retain sync logs (default: `90`)

#### Node Environment
- `NODE_ENV` - Set to `"production"` for production environment

## Example `.env` File

Create `backend/.env`:

```env
# Core
PORT=8787
BASE_URL=http://127.0.0.1:8787

# Database (optional - if not set, uses JSON file storage)
DATABASE_URL=postgres://user:password@localhost:5432/digital_vision_board

# Firebase (optional - for Firebase auth exchange)
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}

# Gemini AI (optional - for wizard recommendations)
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-1.5-flash

# Pexels (optional - for stock images)
PEXELS_API_KEY=your_pexels_api_key_here

# CORS (optional)
CORS_ORIGIN=*

# Node Environment
NODE_ENV=development
```

## Notes

1. **Database**: If `DATABASE_URL` is not set, the backend will use JSON file storage in `backend/data/`. This is fine for development but not recommended for production.

2. **Firebase**: Only needed if you're using Firebase authentication. The backend supports guest authentication without Firebase.

3. **Gemini & Pexels**: These are optional features. The app will work without them, but wizard recommendations and stock image search won't be available.
