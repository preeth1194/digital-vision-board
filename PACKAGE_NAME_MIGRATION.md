# Package Name Migration: com.example.digital_vision_board → com.intent.app

## Changes Made

✅ **Updated files:**
- `android/app/build.gradle.kts` - Changed `namespace` and `applicationId` to `com.intent.app`
- `android/app/src/main/kotlin/com/intent/app/MainActivity.kt` - Package declaration updated to `com.intent.app`
- `android/app/src/main/kotlin/com/intent/app/HabitProgressAppWidget.kt` - Package declaration updated to `com.intent.app`
- `ios/Runner.xcodeproj/project.pbxproj` - Updated bundle identifiers to `com.intent.app`
- `macos/Runner.xcodeproj/project.pbxproj` - Updated bundle identifiers to `com.intent.app`
- `macos/Runner/Configs/AppInfo.xcconfig` - Updated bundle identifier and copyright to `com.intent.app`
- `windows/runner/Runner.rc` - Updated company name and copyright to `com.intent.app`
- `linux/CMakeLists.txt` - Updated `APPLICATION_ID` to `com.intent.app`

✅ **Kotlin files moved:**
- Files moved from `android/app/src/main/kotlin/com/example/digital_vision_board/` to `android/app/src/main/kotlin/com/intent/app/`
- Old directory structure removed

## Update Google Play Secret

After moving files, update your GitHub secret:

**Old:** `PLAY_PACKAGE_NAME = com.example.digital_vision_board`  
**New:** `PLAY_PACKAGE_NAME = com.intent.app`

## Verify Changes

After moving files, verify:
1. ✅ Package declarations in Kotlin files match directory structure
2. ✅ `build.gradle.kts` has correct `namespace` and `applicationId`
3. ✅ GitHub secret `PLAY_PACKAGE_NAME` is updated
4. ✅ Build succeeds: `flutter build appbundle --release`

## Why This Change?

- `com.example.*` is restricted by Google Play
- `com.intent.app` matches your app's brand name ("Intent")
- Must be done before first production release

## Next Steps

1. Move Kotlin files to new directory structure
2. Update `PLAY_PACKAGE_NAME` GitHub secret to `com.intent.app`
3. Test build locally: `flutter clean && flutter build appbundle --release`
4. Push changes and verify CI/CD build succeeds
