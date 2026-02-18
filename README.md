# digital-vision-board
A gamified digital vision board app built with Flutter.

## Firebase / FlutterFire Setup

The app uses Firebase Auth (Google Sign-In, phone auth). To configure Firebase locally:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android (package: `com.seerohabitseeding.app`) and iOS (bundle: `com.seerohabitseeding.app`) apps
3. Run `flutterfire configure` from the project root

See **[FLUTTER_FIRE_SETUP.md](FLUTTER_FIRE_SETUP.md)** for detailed steps.

## CI/CD Workflows

### Testing and Staging Builds
The repository includes a comprehensive testing and staging workflow (`.github/workflows/test_and_staging_build.yml`) that:

- **Runs automatically on pull requests** to `master`, `main`, or `dev` branches
- **Can be triggered manually** via GitHub Actions workflow dispatch
- **Executes Flutter tests** with coverage reporting
- **Builds staging versions** for multiple platforms:
  - Android APK (debug/staging build)
  - iOS (unsigned build for testing, requires macOS runner)
  - Web (static build)
- **Uploads artifacts** for easy distribution to testers
- **Optionally deploys** to Firebase App Distribution (staging track) or Firebase Hosting

#### Test Coverage
- Tests run with coverage collection using Flutter's built-in coverage tool
- Coverage reports are generated in LCOV format
- Coverage artifacts are uploaded and retained for 30 days
- Coverage threshold checking (currently set to 0% - adjust as needed)

#### Triggering Staging Builds
1. **Automatic**: Create a pull request to `master`, `main`, or `dev`
2. **Manual**: Go to Actions → "Test and Staging Build" → Run workflow

#### Staging Build Artifacts
After a successful workflow run, you can download:
- `android-staging-apk`: Debug APK for Android testing
- `ios-staging-build`: Unsigned iOS build (requires code signing for device installation)
- `web-staging-build`: Static web files ready for deployment
- `test-coverage`: Coverage reports in LCOV and HTML formats

#### Optional Secrets for Staging Deployments
- **Firebase App Distribution (staging)**
  - `FIREBASE_APP_ID`
  - `FIREBASE_TOKEN`
  - `FIREBASE_TESTERS` (optional)
  - `FIREBASE_STAGING_GROUPS` (optional, defaults to "staging")
- **Firebase Hosting (staging)**
  - `FIREBASE_TOKEN`
  - `FIREBASE_SERVICE_ACCOUNT`
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_HOSTING_TARGET` (optional, defaults to "default")

### Production Release Builds
The production workflow (`.github/workflows/android_release.yml`) runs on pushes to `master` (including PR merges) and:

- **Runs tests** (must pass before builds proceed)
- **Collects test coverage** and uploads reports
- **Builds release AAB and APK** (signed with production keystore)
- **Uploads them as workflow artifacts**
- **Optionally deploys**:
  - **Google Play (internal track)** from the AAB
  - **Firebase App Distribution** from the APK

#### Required secrets (only if you want signed release builds)
- **ANDROID_KEYSTORE_BASE64**: base64 of your `*.jks`
- **ANDROID_KEYSTORE_PASSWORD**
- **ANDROID_KEY_ALIAS**
- **ANDROID_KEY_PASSWORD**

#### Optional secrets (enable real deployment)
- **Google Play**
  - **PLAY_SERVICE_ACCOUNT_JSON**
  - **PLAY_PACKAGE_NAME**
- **Firebase App Distribution**
  - **FIREBASE_APP_ID**
  - **FIREBASE_TOKEN**
  - (optional) **FIREBASE_TESTERS**, **FIREBASE_GROUPS**

## Testing

### Running Tests Locally
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# View coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Test Files
- Main test file: `test/widget_test.dart`
- Add new tests in the `test/` directory

### Platform-Specific Notes

#### iOS Staging Builds
- iOS builds in CI require macOS runners (more expensive)
- Staging builds are unsigned and cannot be installed on devices without additional code signing
- For production iOS builds, use Xcode or TestFlight
- The workflow will continue even if iOS build fails (marked with `continue-on-error: true`)

#### Web Staging Builds
- Web builds generate static files in `build/web/`
- Can be deployed to any static hosting service
- Optional Firebase Hosting deployment is configured in the workflow
