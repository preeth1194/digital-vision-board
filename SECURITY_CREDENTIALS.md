# Security: Exposed API Keys

If you received a notification that a Google API key was exposed (e.g. in a public GitHub repo), follow these steps.

## Immediate Actions

### 1. Regenerate the compromised API key

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → select project **seerohabitseeding**
2. Navigate to **APIs & Services** → **Credentials**
3. Find the exposed key (`AIzaSyBkLBSVo93NBn8sUaR-s-yzMhBf2mwFI4w` for Android)
4. Click the key → **Regenerate key** (or create a new API key and delete the old one after migration)

### 2. Add API key restrictions

For each Firebase API key, add restrictions to limit abuse:

- **Application restrictions**:
  - **Android**: Restrict to package name `com.seerohabitseeding.app` and your app’s SHA-1 certificate fingerprint
  - **iOS**: Restrict to bundle ID `com.seerohabitseeding.app`
  - **Web**: Restrict to your domain(s) if applicable

- **API restrictions**: Restrict to only the APIs you use (e.g. Firebase services, Identity Toolkit)

To get your Android SHA-1:
```bash
cd android && ./gradlew signingReport
```

### 3. Regenerate Firebase config files

After creating the new key and adding restrictions:

```bash
flutterfire configure --project=seerohabitseeding
```

This updates:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

### 4. Remove native config from public source control

`google-services.json` and `GoogleService-Info.plist` are in `.gitignore`. Do not commit them. Each developer runs `flutterfire configure` locally to generate them.

If these were previously committed:
- Regenerate the keys (steps 1–3)
- Remove from tracking: `git rm --cached android/app/google-services.json ios/Runner/GoogleService-Info.plist macos/Runner/GoogleService-Info.plist`
- Commit the removal

`lib/firebase_options.dart` remains in the repo (needed for compilation). Ensure API key restrictions in GCP are set so the key cannot be abused even if visible.

## For CI/CD

If your CI needs these files to build:
- Store the config files (or their contents) in encrypted secrets
- Inject them at build time instead of committing them to the repo

## References

- [Handling compromised GCP credentials](https://cloud.google.com/iam/docs/credentials-compromised)
- [Firebase API keys](https://firebase.google.com/docs/projects/api-keys)
