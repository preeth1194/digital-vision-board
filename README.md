# digital-vision-board
A gamified digital vision board app built with Flutter.

## CI: Android build + deployment on merge to `master`
This repo includes a GitHub Actions workflow (`.github/workflows/android_release.yml`) that runs on pushes to `master` (including PR merges) and:

- Builds **release AAB** and **release APK**
- Uploads them as workflow artifacts
- Optionally deploys:
  - **Google Play (internal track)** from the AAB
  - **Firebase App Distribution** from the APK

### Required secrets (only if you want signed release builds)
- **ANDROID_KEYSTORE_BASE64**: base64 of your `*.jks`
- **ANDROID_KEYSTORE_PASSWORD**
- **ANDROID_KEY_ALIAS**
- **ANDROID_KEY_PASSWORD**

### Optional secrets (enable real deployment)
- **Google Play**
  - **PLAY_SERVICE_ACCOUNT_JSON**
  - **PLAY_PACKAGE_NAME**
- **Firebase App Distribution**
  - **FIREBASE_APP_ID**
  - **FIREBASE_TOKEN**
  - (optional) **FIREBASE_TESTERS**, **FIREBASE_GROUPS**
