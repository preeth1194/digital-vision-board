# Package Name Migration: com.example.digital_vision_board → com.intent.app

## Changes Made

✅ **Updated files:**
- `android/app/build.gradle.kts` - Changed `namespace` and `applicationId` to `com.intent.app`
- `android/app/src/main/kotlin/com/example/digital_vision_board/MainActivity.kt` - Updated package declaration
- `android/app/src/main/kotlin/com/example/digital_vision_board/HabitProgressAppWidget.kt` - Updated package declaration
- `linux/CMakeLists.txt` - Updated `APPLICATION_ID` to `com.intent.app`

## Important: Move Kotlin Source Files

The Kotlin files still need to be moved to match the new package structure:

**Current location:**
```
android/app/src/main/kotlin/com/example/digital_vision_board/
```

**New location:**
```
android/app/src/main/kotlin/com/intent/app/
```

### How to Move (choose one method):

#### Method 1: Using Android Studio (Recommended)
1. Right-click on `com/example/digital_vision_board` folder
2. Select **Refactor** → **Move**
3. Enter new package: `com.intent.app`
4. Android Studio will move files and update all references

#### Method 2: Manual Move
```bash
cd android/app/src/main/kotlin
mkdir -p com/intent/app
mv com/example/digital_vision_board/*.kt com/intent/app/
rm -rf com/example
```

#### Method 3: Git Move (preserves history)
```bash
cd android/app/src/main/kotlin
git mv com/example/digital_vision_board com/intent/app
```

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
