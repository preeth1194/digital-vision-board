# FlutterFire Setup Guide

This project uses Firebase Auth (Google Sign-In, phone auth) for login. FlutterFire config is in place for project **seerohabitseeding**.

## Prerequisites

1. **Firebase CLI** (for project management):
   ```bash
   npm install -g firebase-tools
   ```

2. **Log in to Firebase**:
   ```bash
   firebase login
   ```

3. **FlutterFire CLI**:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   Ensure `$HOME/.pub-cache/bin` is in your `PATH`.

## Firebase Console Configuration (Required for Login)

In [Firebase Console](https://console.firebase.google.com/) for project **seerohabitseeding**:

### 1. Enable sign-in methods

- Go to **Authentication > Sign-in method**
- Enable **Google**
- Enable **Phone**

### 2. Add Android SHA fingerprints (required for Google Sign-In)

Run from the project root:

```bash
cd android && ./gradlew signingReport
```

Copy the **SHA-1** and **SHA-256** from the `debug` and `release` variants. In Firebase Console:

- Go to **Project settings > Your apps > Android** (package: `com.seerohabitseeding.app`)
- Add each SHA fingerprint under "SHA certificate fingerprints"

### 3. Backend service account (required for Firebase token exchange)

The app exchanges Firebase idToken for a backend dvToken via `POST /auth/firebase/exchange`. The backend must verify tokens using a Firebase Admin service account.

1. Firebase Console > **Project settings > Service accounts**
2. Click **Generate new private key**
3. Add to `backend/.env`:
   ```
   FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"seerohabitseeding",...}
   ```
   Use the full JSON content (as a single line, escaped if needed).

Without this, Google and phone login will fail when exchanging the token.

## Re-running FlutterFire Configure

If you add platforms or need to regenerate config:

```bash
flutterfire configure --project=seerohabitseeding
```

## Verify

```bash
flutter pub get
flutter run
```

Google Sign-In and phone auth should work once the above steps are complete.
